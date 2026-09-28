import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/core/mock/mock_data.dart';
import 'package:palengkego/features/vendors/domain/sales_summary.dart';
import 'package:palengkego/features/vendors/domain/vendor_repository.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';
import 'package:palengkego/features/vendors/domain/vendor_profile.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';

class MockVendorRepository implements VendorRepository {
  MockVendorRepository([this._prefs]);
  final SharedPreferences? _prefs;

  static const _customProductsKey = 'vendor_custom_products_v1';
  static const _mockStallKey = 'vendor_custom_stall_v1';

  Future<VendorStall?> _loadPersistedStall() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(_mockStallKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return VendorStall.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePersistedStall(VendorStall stall) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_mockStallKey, jsonEncode(stall.toJson()));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _loadPersistedProducts() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(_customProductsKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePersistedProducts(List<Map<String, dynamic>> items) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_customProductsKey, jsonEncode(items));
    } catch (_) {}
  }

  Future<List<VendorProduct>> getAllCustomProducts() async {
    final persisted = await _loadPersistedProducts();
    return persisted.map((p) {
      final stock = (p['stockQuantity'] as num?)?.toDouble() ?? 15.0;
      final explicitlyActive = p['isActive'] as bool? ?? true;
      final active = explicitlyActive && stock > 0;
      return VendorProduct(
        id: p['id'] as String? ?? '',
        vendorId: p['vendorId'] as String? ?? '',
        name: p['name'] as String? ?? '',
        category: p['category'] as String? ?? '',
        price: (p['price'] as num?)?.toDouble() ?? 0.0,
        description: p['description'] as String? ?? '',
        unit: p['unit'] as String? ?? 'kg',
        imageUrl: p['imageUrl'] as String? ?? '',
        isActive: active,
        stockQuantity: stock,
        discountPercentage: (p['discountPercentage'] as num?)?.toDouble(),
      );
    }).toList();
  }

  @override
  Future<VendorProfile> getVendorProfile(String id) async {
    final savedStall = await _loadPersistedStall();
    if (savedStall != null) {
      _mockStall = savedStall;
    }
    final effectiveStall = savedStall ?? _mockStall;

    // Find the vendor in MockDataService.featuredVendors
    final vendorMap = MockDataService.featuredVendors.firstWhere(
      (v) => v['id'] == id,
      orElse: () => {
        'id': id,
        'name': 'Market Stall',
        'category': 'General',
        'rating': 0.0,
        'reviewCount': 0,
        'stallNumber': 'Market Stall',
        'isOpen': true,
      },
    );

    // Compute reviews count and average rating dynamically from the reviews list
    final reviews = MockDataService.getReviewsAsObjects(id);
    final double rating;
    final int reviewCount = reviews.length;
    if (reviews.isEmpty) {
      rating = 0.0;
    } else {
      final totalRating = reviews.map((r) => r.rating).reduce((a, b) => a + b);
      rating = double.parse((totalRating / reviewCount).toStringAsFixed(1));
    }

    final isTargetVendor = (effectiveStall.stallId.isNotEmpty && id == effectiveStall.stallId) ||
        (effectiveStall.ownerUid.isNotEmpty && id == effectiveStall.ownerUid) ||
        (id == 'v1') ||
        (id == 'stall holder-001');

    if (isTargetVendor) {
      final img = (effectiveStall.bannerImage != null && effectiveStall.bannerImage!.isNotEmpty)
          ? effectiveStall.bannerImage!
          : (effectiveStall.thumbnailImage ??
              vendorMap['bannerUrl'] as String? ??
              vendorMap['imageUrl'] as String? ??
              '');
      final av = effectiveStall.avatarImage ??
          vendorMap['avatarUrl'] as String? ??
          '';
      return VendorProfile(
        id: id,
        name: effectiveStall.name,
        category: effectiveStall.category,
        rating: rating > 0 ? rating : effectiveStall.averageRating,
        reviewCount:
            reviewCount > 0 ? reviewCount : effectiveStall.totalRatings,
        isOpen: effectiveStall.isOpen,
        stallLocation: effectiveStall.location.isNotEmpty
            ? effectiveStall.location
            : (vendorMap['stallNumber'] as String? ?? 'Market Stall'),
        imageUrl: img,
        avatarUrl: av,
        phoneNumber: vendorMap['phoneNumber'] as String? ?? '+63 912 345 6789',
        description: effectiveStall.description.isNotEmpty
            ? effectiveStall.description
            : 'Fresh ${effectiveStall.category.toLowerCase()} directly to your doorstep. Quality and freshness guaranteed!',
      );
    }

    return VendorProfile(
      id: vendorMap['id'] as String? ?? '',
      name: vendorMap['name'] as String? ?? 'Stall Holder',
      category: vendorMap['category'] as String? ?? 'General',
      rating: rating,
      reviewCount: reviewCount,
      isOpen: vendorMap['isOpen'] as bool? ?? (id != 'v3'),
      stallLocation: vendorMap['stallNumber'] as String? ?? 'Market Stall',
      imageUrl:
          vendorMap['bannerUrl'] as String? ??
          vendorMap['imageUrl'] as String? ??
          '',
      avatarUrl:
          vendorMap['avatarUrl'] as String? ??
          (id == 'v2'
              ? 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=200&h=200&fit=crop&crop=face'
              : 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop&crop=face'),
      phoneNumber: vendorMap['phoneNumber'] as String? ?? '+63 912 345 6789',
      description: vendorMap['description'] as String? ??
          'Fresh ${vendorMap['category'] ?? 'products'} directly to your doorstep. Quality and freshness guaranteed!',
    );
  }

  @override
  Future<List<VendorProduct>> getVendorProducts(String vendorId) async {
    final effectiveVendorId =
        (vendorId == 'stall holder-001' || vendorId == 'vendor-001')
            ? 'v1'
            : vendorId;

    final persisted = await _loadPersistedProducts();
    for (final p in persisted) {
      final index = MockDataService.products.indexWhere((m) => m['id'] == p['id']);
      if (index != -1) {
        MockDataService.products[index] = p;
      } else {
        MockDataService.products.add(p);
      }
    }

    final rawProducts = MockDataService.getProductsForVendor(effectiveVendorId);

    // Also include any persisted custom products matching vendorId / effectiveVendorId
    final combinedRaw = <Map<String, dynamic>>[...rawProducts];
    for (final p in persisted) {
      final pVendor = p['vendorId']?.toString();
      final isMatch = pVendor == vendorId ||
          pVendor == effectiveVendorId ||
          pVendor == 'v1' ||
          effectiveVendorId == 'v1' ||
          pVendor == _mockStall.stallId ||
          pVendor == _mockStall.ownerUid;
      if (isMatch && !combinedRaw.any((m) => m['id'] == p['id'])) {
        combinedRaw.add(p);
      }
    }

    return combinedRaw.asMap().entries.map((entry) {
      final p = entry.value;

      // Use the stored stockQuantity directly; fall back to 15 for legacy
      // mock rows that have no stockQuantity field yet.
      // NOTE: never derive stock from list index — that causes the wrong
      // product to appear out-of-stock when another product is deleted.
      final stock = (p['stockQuantity'] as num?)?.toDouble() ?? 15.0;

      // Respect the explicitly-saved isActive flag; if stock hits 0 the
      // product is also treated as inactive regardless of the flag.
      final explicitlyActive = p['isActive'] as bool? ?? true;
      final active = explicitlyActive && stock > 0;

      return VendorProduct(
        id: p['id'] as String? ?? '',
        vendorId: p['vendorId'] as String? ?? '',
        name: p['name'] as String? ?? '',
        category: p['category'] as String? ?? '',
        price: (p['price'] as num?)?.toDouble() ?? 0.0,
        description: p['description'] as String? ?? '',
        unit: p['unit'] as String? ?? 'kg',
        imageUrl: p['imageUrl'] as String? ?? '',
        isActive: active,
        stockQuantity: stock,
        discountPercentage: (p['discountPercentage'] as num?)?.toDouble(),
      );
    }).toList();
  }

  @override
  Future<VendorProduct> addVendorProduct(VendorProduct product) async {
    await Future.delayed(const Duration(milliseconds: 300));
    MockDataService.addProduct(product.toJson());
    final persisted = await _loadPersistedProducts();
    persisted.removeWhere((p) =>
        p['id'] == product.id ||
        (p['name'] != null &&
            p['name'].toString().toLowerCase().trim() ==
                product.name.toLowerCase().trim()));
    persisted.add(product.toJson());
    await _savePersistedProducts(persisted);
    return product;
  }

  @override
  Future<VendorProduct> updateVendorProduct(VendorProduct product) async {
    await Future.delayed(const Duration(milliseconds: 300));
    MockDataService.updateProduct(product.toJson());
    final persisted = await _loadPersistedProducts();
    final index = persisted.indexWhere((p) =>
        p['id'] == product.id ||
        (p['name'] != null &&
            p['name'].toString().toLowerCase().trim() ==
                product.name.toLowerCase().trim()));
    if (index != -1) {
      persisted[index] = product.toJson();
    } else {
      persisted.add(product.toJson());
    }
    await _savePersistedProducts(persisted);
    return product;
  }

  @override
  Future<void> deleteVendorProduct(String stallId, String productId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    MockDataService.deleteProduct(productId);
    final persisted = await _loadPersistedProducts();
    persisted.removeWhere((p) =>
        p['id'] == productId ||
        (p['name'] != null &&
            p['name'].toString().toLowerCase().trim() ==
                productId.toLowerCase().trim()));
    await _savePersistedProducts(persisted);
  }

  // ── Stall management ───────────────────────────────────────────────────────

  // Cached mock stall for the in-memory vendor.
  VendorStall _mockStall = const VendorStall(
    stallId: 'v1',
    ownerUid: 'stall holder-001',
    name: "Diosa Fruit Stand",
    description:
        'Fresh products directly to your doorstep. Quality and freshness guaranteed!',
    category: 'Fruits',
    location: 'Stall 14, Wet Market Section',
    stallNumber: '14',
    section: 'Wet Market',
    isOpen: true,
    averageRating: 4.7,
    totalRatings: 112,
  );

  @override
  Future<VendorStall> getVendorStall(String stallId) async {
    final saved = await _loadPersistedStall();
    if (saved != null) {
      _mockStall = saved;
    }
    final effectiveStallId = (stallId == 'stall holder-001' || stallId == 'vendor-001') ? 'v1' : stallId;
    return _mockStall.copyWith(stallId: effectiveStallId);
  }

  @override
  Future<void> updateVendorStall(VendorStall stall) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _mockStall = stall;
    await _savePersistedStall(stall);

    // Sync to featuredVendors list so it reflects in the Customer UI profile views
    final mockId = stall.ownerUid == 'stall holder-001' ? 'v1' : stall.stallId;
    int index = MockDataService.featuredVendors.indexWhere(
      (v) => v['id'] == mockId || v['id'] == stall.stallId || v['id'] == stall.ownerUid,
    );
    if (index == -1 && (stall.ownerUid == 'stall holder-001' || stall.stallId == 'v1' || mockId == 'v1')) {
      index = MockDataService.featuredVendors.indexWhere((v) => v['id'] == 'v1');
    }

    if (index != -1) {
      final existing = MockDataService.featuredVendors[index];
      MockDataService.featuredVendors[index] = {
        ...existing,
        'name': stall.name,
        'category': stall.category,
        'imageUrl':
            stall.thumbnailImage ?? stall.bannerImage ?? existing['imageUrl'],
        'bannerUrl':
            stall.bannerImage ?? existing['bannerUrl'] ?? existing['imageUrl'],
        'avatarUrl': stall.avatarImage ?? existing['avatarUrl'],
        'isOpen': stall.isOpen,
        'stallNumber': stall.location,
        'description': stall.description,
      };
    } else {
      MockDataService.featuredVendors.add({
        'id': stall.stallId,
        'name': stall.name,
        'category': stall.category,
        'imageUrl': stall.thumbnailImage ?? stall.bannerImage ?? '',
        'bannerUrl': stall.bannerImage ?? '',
        'avatarUrl': stall.avatarImage ?? '',
        'isOpen': stall.isOpen,
        'stallNumber': stall.location,
        'rating': stall.averageRating,
        'reviewCount': stall.totalRatings,
        'description': stall.description,
      });
    }
  }

  // ── Reviews ────────────────────────────────────────────────────────────────

  @override
  Future<List<VendorReview>> getReviews(String stallId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return MockDataService.getReviewsAsObjects(stallId);
  }

  @override
  Future<void> addReview(VendorReview review) async {
    await Future.delayed(const Duration(milliseconds: 300));
    MockDataService.addReview({
      'id': review.id,
      'vendorId': review.vendorId,
      'customerName': review.customerName,
      'rating': review.rating,
      'comment': review.comment,
      'date': review.date.toIso8601String(),
      'reviewType': review.reviewType == ReviewType.product
          ? 'product'
          : 'vendor',
      'productName': review.productName,
    });
  }

  // ── Sales / Earnings ───────────────────────────────────────────────────────

  @override
  Future<List<SalesSummary>> getSalesSummary(
    String stallId, {
    required DateTime from,
    required DateTime to,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // For newly registered stallholders (not legacy demo stalls 'v1' / 'stall holder-001'),
    // newly created accounts have 0 initial earnings until real orders are completed.
    if (stallId != 'v1' && stallId != 'stall holder-001') {
      return const [];
    }
    // Generate plausible mock daily sales between [from] and [to] for demo stalls.
    final summaries = <SalesSummary>[];
    var cursor = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    int index = 0;
    while (!cursor.isAfter(end)) {
      // Vary revenue day by day for a realistic chart shape.
      final revenue = 800.0 + (index % 7) * 200.0 + (index % 3) * 150.0;
      summaries.add(
        SalesSummary(
          summaryId: cursor.toIso8601String().split('T').first,
          stallId: stallId,
          date: cursor,
          totalOrders: 3 + index % 5,
          totalRevenue: revenue,
          totalItemsSold: 8 + index % 10,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
      index++;
    }
    return summaries;
  }
}
