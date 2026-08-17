import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:palengkego/features/market/domain/market_product.dart';
import 'package:palengkego/features/market/domain/market_repository.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';

/// Pure mapping from a Firestore `vendorStalls/{stallId}` document to a
/// [MarketVendor]. Kept top-level (no SDK types) so contract tests run
/// without a Firestore emulator.
MarketVendor stallToMarketVendor(String id, Map<String, dynamic> data) {
  return MarketVendor(
    id: id,
    name: data['name'] as String? ?? '',
    category: data['category'] as String? ?? '',
    rating: (data['averageRating'] as num?)?.toDouble() ?? 0,
    isVerified: data['isKYCApproved'] as bool? ?? false,
    distance: data['distance'] as String? ?? '',
    imageUrl: data['bannerImage'] as String? ?? '',
    stallNumber: data['stallNumber'] as String?,
    marketSection: data['marketSection'] as String?,
    reviewCount: data['totalRatings'] as int? ?? 0,
    topReviewText: data['topReviewText'] as String?,
    isOpen: data['isOpen'] as bool? ?? true,
    tags: (data['tags'] as List?)?.cast<String>(),
  );
}

/// Pure mapping from a Firestore `vendorStalls/{stallId}/products/{id}`
/// document to a [VendorProduct].
VendorProduct productFromStorageDoc(String id, Map<String, dynamic> data) {
  return VendorProduct(
    id: id,
    vendorId: data['vendorId'] as String? ?? '',
    name: data['name'] as String? ?? '',
    description: data['description'] as String? ?? '',
    category: data['category'] as String? ?? '',
    price: (data['price'] as num?)?.toDouble() ?? 0,
    unit: data['unit'] as String? ?? 'kg',
    imageUrl: data['imageUrl'] as String? ?? '',
    isActive: data['isActive'] as bool? ?? true,
    stockQuantity: (data['stockQuantity'] as num?)?.toDouble() ?? 0.0,
    initialStockQuantity:
        (data['initialStockQuantity'] as num?)?.toDouble() ?? 0.0,
    discountPercentage: (data['discountPercentage'] as num?)?.toDouble(),
  );
}

/// Mirrors [MockMarketRepository.getVendorsByCategory] filtering: matches
/// stall category, the Maritatas/Sari-Sari alias buckets, or any product
/// whose category contains the requested one.
bool vendorMatchesCategory(
  MarketVendor vendor,
  List<VendorProduct> products,
  String category,
) {
  final lowerCategory = category.toLowerCase();
  if (vendor.category.toLowerCase().contains(lowerCategory)) return true;

  if (category == 'Maritatas' || category == 'Sari-Sari') {
    if (_isMaritataCategory(vendor.category)) return true;
  }

  return products.any((p) {
    final lowerProdCat = p.category.toLowerCase();
    if (lowerProdCat.contains(lowerCategory)) return true;
    return (category == 'Maritatas' || category == 'Sari-Sari') &&
        _isMaritataCategory(p.category);
  });
}

bool _isMaritataCategory(String category) {
  final lower = category.toLowerCase();
  return lower.contains('rice') ||
      lower.contains('grains') ||
      lower.contains('spice') ||
      lower.contains('condiment');
}

/// Firestore implementation of [MarketRepository].
///
/// Collections (public read via `firestore.rules`):
///   `vendorStalls/{stallId}`            — market vendors
///   `vendorStalls/{stallId}/products/{productId}` — catalog products
///
/// Live reads never fall back to mock data (T6.5): a missing stall simply
/// means no vendor, an empty list, no unrelated seeded rows.
class FirebaseMarketRepository implements MarketRepository {
  FirebaseMarketRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<List<Map<String, dynamic>>> _stallDocs({
    bool approvedOnly = true,
  }) async {
    final query = approvedOnly
        ? _firestore
              .collection('vendorStalls')
              .where('isKYCApproved', isEqualTo: true)
        : _firestore.collection('vendorStalls');
    final snap = await query.get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<List<MarketVendor>> getFeaturedVendors() async {
    final stalls = await _stallDocs();
    final vendors =
        stalls
            .map(
              (d) => stallToMarketVendor(
                d['id']! as String,
                Map<String, dynamic>.from(d),
              ),
            )
            .toList()
          ..sort((a, b) {
            final byRating = b.rating.compareTo(a.rating);
            return byRating != 0
                ? byRating
                : b.reviewCount.compareTo(a.reviewCount);
          });
    return vendors;
  }

  @override
  Future<List<MarketVendor>> getVendorsByCategory(String category) async {
    final vendors = await getFeaturedVendors();
    if (category == 'All') return List.unmodifiable(vendors);

    final filtered = <MarketVendor>[];
    for (final vendor in vendors) {
      final products = await getProductsForVendor(vendor.id);
      if (vendorMatchesCategory(vendor, products, category)) {
        filtered.add(vendor);
      }
    }
    return filtered;
  }

  @override
  Future<List<VendorProduct>> getProductsForVendor(String vendorId) async {
    final snap = await _firestore
        .collection('vendorStalls')
        .doc(vendorId)
        .collection('products')
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.map((d) => productFromStorageDoc(d.id, d.data())).toList();
  }

  @override
  Future<List<VendorProduct>> getDiscountedProducts() async {
    final all = await getAllProducts();
    return all.where((p) => p.hasDiscount).toList();
  }

  @override
  Future<List<VendorProduct>> getAllProducts() async {
    final stalls = await _stallDocs(approvedOnly: false);
    final products = <VendorProduct>[];
    for (final stall in stalls) {
      products.addAll(await getProductsForVendor(stall['id']! as String));
    }
    return products;
  }
}
