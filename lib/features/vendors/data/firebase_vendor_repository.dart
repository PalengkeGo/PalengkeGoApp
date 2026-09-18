import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/features/vendors/domain/sales_summary.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';
import 'package:palengkego/features/vendors/domain/vendor_profile.dart';
import 'package:palengkego/features/vendors/domain/vendor_repository.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';

/// Firestore implementation of [VendorRepository].
///
/// Collections:
///   `vendorStalls/{stallId}`
///   `vendorStalls/{stallId}/products/{productId}`
///   `ratings/{ratingId}`
///   `salesSummary/{stallId}/daily/{date}`
class FirebaseVendorRepository implements VendorRepository {
  FirebaseVendorRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // ── Market listing (customer-facing) ────────────────────────────────────────

  @override
  Future<VendorProfile> getVendorProfile(String id) async {
    // Public storefront fields live on stallCatalog (audit 2026-09-13 M2).
    final doc = await _firestore.collection('stallCatalog').doc(id).get();
    if (!doc.exists) {
      // T6.5: a missing stall is a documented empty profile — never mock
      // rows in a live get() path.
      return VendorProfile(
        id: id,
        name: '',
        category: '',
        rating: 0,
        reviewCount: 0,
        isOpen: false,
        stallLocation: '',
        imageUrl: '',
        avatarUrl: '',
      );
    }
    final d = doc.data()!;
    return VendorProfile(
      id: id,
      name: d['name'] as String? ?? '',
      category: d['category'] as String? ?? '',
      rating: (d['averageRating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: d['totalRatings'] as int? ?? 0,
      isOpen: d['isOpen'] as bool? ?? false,
      stallLocation: d['location'] as String? ?? '',
      imageUrl: d['bannerImage'] as String? ?? '',
      avatarUrl: d['avatarImage'] as String? ?? '',
    );
  }

  @override
  Future<List<VendorProduct>> getVendorProducts(String vendorId) async {
    final snap = await _firestore
        .collection('vendorStalls')
        .doc(vendorId)
        .collection('products')
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.map((d) => _productFromFirestore(d.id, d.data())).toList();
  }

  // ── Product management ───────────────────────────────────────────────────────

  @override
  Future<VendorProduct> addVendorProduct(VendorProduct product) async {
    final ref = _firestore
        .collection('vendorStalls')
        .doc(product.vendorId)
        .collection('products')
        .doc();
    final saved = VendorProduct(
      id: ref.id,
      vendorId: product.vendorId,
      name: product.name,
      category: product.category,
      price: product.price,
      description: product.description,
      unit: product.unit,
      imageUrl: product.imageUrl,
      isActive: product.isActive,
      stockQuantity: product.stockQuantity,
      discountPercentage: product.discountPercentage,
    );
    await ref.set(_productToFirestore(saved));
    return saved;
  }

  @override
  Future<VendorProduct> updateVendorProduct(VendorProduct product) async {
    await _firestore
        .collection('vendorStalls')
        .doc(product.vendorId)
        .collection('products')
        .doc(product.id)
        .set(_productToFirestore(product), SetOptions(merge: true));
    return product;
  }

    @override
  Future<void> deleteVendorProduct(String stallId, String productId) async {
    // Real delete against Firestore; the security rules scope deletes to the
    // stall owner (ownsStall), so a forged stallId/productId combination is
    // denied server-side, not just here.
    final ref = _firestore
        .collection('vendorStalls')
        .doc(stallId)
        .collection('products')
        .doc(productId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception('Product $productId not found in stall $stallId');
    }
    await ref.delete();
  }

  // ── Stall management ────────────────────────────────────────────────────────

  /// Stall fields owned by the trusted backend — KYC/license state is stamped
  /// by the admin callables (approveKyc/approveRenewal), the rating aggregate
  /// by addReview, and stallNumber/floorNumber/section are assigned at KYC
  /// approval. The security rules deny client writes to all of them (audit
  /// 2026-08-23 H1), so they are stripped from the payload: echoing them
  /// back would fail the WHOLE update whenever the server-side value changed
  /// since this client read it (e.g. a review landed mid-edit).
  static const _serverOwnedStallFields = {
    'ownerUid',
    'isKYCApproved',
    'kycStatus',
    'licenseStatus',
    'licenseExpiryDate',
    'averageRating',
    'totalRatings',
    'stallNumber',
    'floorNumber',
    'section',
    'createdAt',
  };

  @override
  Future<VendorStall> getVendorStall(String stallId) async {
    // Merged view (audit 2026-09-13 M2): public storefront fields live on
    // stallCatalog (world-readable, may not exist until approval/backfill);
    // the private record (ownerUid, KYC/license state) on vendorStalls,
    // readable by the owner. Private fields overlay catalog fields — the
    // two sets are disjoint by design.
    final privateSnap =
        await _firestore.collection('vendorStalls').doc(stallId).get();
    if (!privateSnap.exists) {
      throw Exception('Stall $stallId not found in Firestore');
    }
    final catalogSnap =
        await _firestore.collection('stallCatalog').doc(stallId).get();
    final merged = <String, dynamic>{
      ...?catalogSnap.data(),
      ...privateSnap.data()!,
    };
    return VendorStall.fromJson({...merged, 'stallId': stallId});
  }

  @override
  Future<void> updateVendorStall(VendorStall stall) async {
    // Every client-writable field is PUBLIC storefront data now (audit
    // 2026-09-13 M2): the payload goes to the world-readable catalog doc,
    // whose id == owner uid so the rules let the owner write it. Server-
    // owned fields (ownerUid, KYC/license state, aggregate, allocation) are
    // stripped — the client never sends them, and the catalog rules deny
    // the badge/aggregate keys outright.
    final payload = Map<String, dynamic>.from(stall.toJson())
      ..remove('stallId')
      ..removeWhere((key, _) => _serverOwnedStallFields.contains(key));
    payload['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore
        .collection('stallCatalog')
        .doc(stall.stallId)
        .set(payload, SetOptions(merge: true));
  }

  // ── Reviews ─────────────────────────────────────────────────────────────────

  @override
  Future<List<VendorReview>> getReviews(String stallId) async {
    final snap = await _firestore
        .collection('ratings')
        .where('vendorId', isEqualTo: stallId)
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return VendorReview(
        id: d.id,
        vendorId: data['vendorId'] as String? ?? '',
        customerId: data['customerId'] as String? ?? '',
        customerName: data['customerName'] as String? ?? '',
        rating: (data['rating'] as num?)?.toDouble() ?? 0,
        comment: data['comment'] as String? ?? '',
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        orderId: data['orderId'] as String?,
        reviewType: data['reviewType'] == 'product'
            ? ReviewType.product
            : ReviewType.vendor,
        productName: data['productName'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> addReview(VendorReview review) async {
    // Trusted path via Supabase Edge Function `add-review`
    // (supabase/functions/add-review — kebab-case): verifies the customer
    // owns a completed order for this stall, enforces one review per order
    // without a check-then-write race, and recomputes the stall rating
    // aggregate in the same transaction.
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to submit a review.');
    }
    final idToken = await user.getIdToken();
    if (idToken == null) {
      throw Exception('You must be signed in to submit a review.');
    }
    final supabaseUrl = AppConfig.load().supabaseUrl;
    final url = Uri.parse(
      '${supabaseUrl.isNotEmpty ? supabaseUrl : 'https://palengkego.supabase.co'}/functions/v1/add-review',
    );
    final resp = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'stallId': review.vendorId,
            'orderId': review.orderId,
            'rating': review.rating,
            'comment': review.comment,
            'reviewType': review.reviewType == ReviewType.product
                ? 'product'
                : 'vendor',
            'productName': review.productName,
            'customerName': review.customerName,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>?;
      final msg = (body?['error'] as Map?)?['message'] as String? ?? resp.body;
      throw Exception('Failed to submit review: $msg');
    }
  }

  // ── Sales summary ────────────────────────────────────────────────────────────

  @override
  Future<List<SalesSummary>> getSalesSummary(
    String stallId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final fromStr = from.toIso8601String().split('T').first;
    final toStr = to.toIso8601String().split('T').first;

    final snap = await _firestore
        .collection('salesSummary')
        .doc(stallId)
        .collection('daily')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: fromStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: toStr)
        .orderBy(FieldPath.documentId)
        .get();

    return snap.docs
        .map((d) => SalesSummary.fromFirestore(d.data(), id: d.id))
        .toList();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> _productToFirestore(VendorProduct p) => {
    'vendorId': p.vendorId,
    'name': p.name,
    'category': p.category,
    'price': p.price,
    'description': p.description,
    'unit': p.unit,
    'imageUrl': p.imageUrl,
    'isActive': p.isActive,
    'stockQuantity': p.stockQuantity,
    'discountPercentage': p.discountPercentage,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  VendorProduct _productFromFirestore(String id, Map<String, dynamic> d) =>
      VendorProduct(
        id: id,
        vendorId: d['vendorId'] as String? ?? '',
        name: d['name'] as String? ?? '',
        category: d['category'] as String? ?? '',
        price: (d['price'] as num?)?.toDouble() ?? 0,
        description: d['description'] as String? ?? '',
        unit: d['unit'] as String? ?? 'kg',
        imageUrl: d['imageUrl'] as String? ?? '',
        isActive: d['isActive'] as bool? ?? true,
        stockQuantity: (d['stockQuantity'] as num?)?.toDouble() ?? 0.0,
        discountPercentage: (d['discountPercentage'] as num?)?.toDouble(),
      );
}