import 'package:palengkego/core/mock/mock_data.dart';
import 'package:palengkego/features/vendors/domain/sales_summary.dart';
import 'package:palengkego/features/vendors/domain/vendor_repository.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';
import 'package:palengkego/features/vendors/domain/vendor_profile.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';

class MockVendorRepository implements VendorRepository {
  @override
  Future<VendorProfile> getVendorProfile(String id) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Find the vendor in MockDataService.featuredVendors
    final vendorMap = MockDataService.featuredVendors.firstWhere(
      (v) => v['id'] == id,
      orElse: () => MockDataService.featuredVendors.first,
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
    );
  }

  @override
  Future<List<VendorProduct>> getVendorProducts(String vendorId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    final rawProducts = MockDataService.getProductsForVendor(vendorId);

    return rawProducts.asMap().entries.map((entry) {
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
    return product;
  }

  @override
  Future<VendorProduct> updateVendorProduct(VendorProduct product) async {
    await Future.delayed(const Duration(milliseconds: 300));
    MockDataService.updateProduct(product.toJson());
    return product;
  }

  @override
  Future<void> deleteVendorProduct(String productId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    MockDataService.deleteProduct(productId);
  }

  // ── Stall management ───────────────────────────────────────────────────────

  // Cached mock stall for the in-memory vendor.
  VendorStall _mockStall = const VendorStall(
    stallId: 'stall holder-001',
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
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockStall;
  }

  @override
  Future<void> updateVendorStall(VendorStall stall) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _mockStall = stall;

    // Sync to featuredVendors list so it reflects in the Customer UI profile views
    final mockId = stall.ownerUid == 'stall holder-001' ? 'v1' : stall.stallId;
    final index = MockDataService.featuredVendors.indexWhere(
      (v) => v['id'] == mockId,
    );

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
      };
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
    // Generate plausible mock daily sales between [from] and [to].
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
