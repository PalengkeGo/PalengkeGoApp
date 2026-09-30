import 'package:palengkego/features/vendors/domain/vendor_review.dart';

class MockDataService {
  static List<Map<String, dynamic>> featuredVendors = [];

  static List<Map<String, dynamic>> products = [];

  static List<Map<String, dynamic>> getProductsForVendor(String vendorId) {
    final existing = products.where((p) {
      final vId = p['vendorId']?.toString();
      if (vId == vendorId) return true;
      if (p['stallHolderId']?.toString() == vendorId) return true;
      if (p['userId']?.toString() == vendorId) return true;
      return false;
    }).toList();
    if (existing.isNotEmpty) {
      final vendor = featuredVendors.firstWhere(
        (v) => v['id'] == vendorId,
        orElse: () => {},
      );
      final vendorCategory = vendor['category'] ?? '';

      return existing.map((p) {
        if (p.containsKey('category')) return p;
        return {...p, 'category': vendorCategory};
      }).toList();
    }

    return [];
  }

  static List<Map<String, dynamic>> getDiscountedProducts() {
    return products
        .where((p) {
          final discount = p['discountPercentage'];
          // Guard: skip products where discountPercentage is null or not a number
          if (discount == null) return false;
          return (discount as num) > 0;
        })
        .map((p) {
          final vendor = featuredVendors.firstWhere(
            (v) => v['id'] == p['vendorId'],
            orElse: () => {},
          );
          final vendorCategory = vendor['category'] ?? '';
          if (p.containsKey('category')) return p;
          return {...p, 'category': vendorCategory};
        })
        .toList();
  }

  static void addProduct(Map<String, dynamic> product) {
    products.add(product);
  }

  static void updateProduct(Map<String, dynamic> product) {
    final index = products.indexWhere(
      (p) =>
          p['id'] == product['id'] ||
          (p['name'] != null &&
              product['name'] != null &&
              p['name'].toString().toLowerCase().trim() ==
                  product['name'].toString().toLowerCase().trim()),
    );
    if (index != -1) {
      products[index] = product;
    } else {
      products.add(product);
    }
  }

  static void deleteProduct(String productId) {
    products.removeWhere((p) => p['id'] == productId);
  }

  static List<Map<String, dynamic>> reviews = [];

  static void decreaseProductStockByName(
    String productName,
    String vendorName,
    double quantity,
  ) {
    final normName = productName.toLowerCase().trim();
    // First try matching by both name and vendor if vendor is known
    final vendor = featuredVendors.firstWhere(
      (v) => v['name'] == vendorName,
      orElse: () => {'id': ''},
    );
    final vendorId = vendor['id'] as String;

    int productIndex = -1;
    if (vendorId.isNotEmpty) {
      productIndex = products.indexWhere(
        (p) =>
            (p['name'] as String? ?? '').toLowerCase().trim() == normName &&
            p['vendorId'] == vendorId,
      );
    }
    // Fall back to matching by name across all products
    if (productIndex == -1) {
      productIndex = products.indexWhere(
        (p) => (p['name'] as String? ?? '').toLowerCase().trim() == normName,
      );
    }

    if (productIndex != -1) {
      final currentStock =
          (products[productIndex]['stockQuantity'] as num?)?.toDouble() ?? 15.0;
      if (products[productIndex]['initialStockQuantity'] == null) {
        products[productIndex]['initialStockQuantity'] = currentStock;
      }
      final newStock = (currentStock - quantity).clamp(0.0, 9999.0);
      products[productIndex]['stockQuantity'] = newStock;
      if (newStock <= 0) {
        products[productIndex]['isActive'] = false;
      }
    }
  }

  /// Maps the demo stall account's uid/stallId ('stall holder-001') to the
  /// mock catalog vendor id ('v1') that keys its reviews and profile.
  static String resolveMockVendorId(String stallIdOrUid) {
    return stallIdOrUid == 'stall holder-001' ? 'v1' : stallIdOrUid;
  }

  static void addReview(Map<String, dynamic> review) {
    reviews.add(review);
  }

  static List<Map<String, dynamic>> getReviewsForVendor(String vendorId) {
    return reviews.where((r) => r['vendorId'] == vendorId).toList();
  }

  /// Returns typed [VendorReview] objects for a given vendor.
  static List<VendorReview> getReviewsAsObjects(String vendorId) {
    return getReviewsForVendor(vendorId).map((r) {
      final isProduct = r['reviewType'] == 'product';
      return VendorReview(
        id: r['id'] as String? ?? '',
        vendorId: r['vendorId'] as String? ?? '',
        customerId: r['customerId'] as String? ?? '',
        customerName: r['customerName'] as String? ?? '',
        rating: (r['rating'] as num).toDouble(),
        comment: r['comment'] as String,
        date: DateTime.parse(r['date'] as String),
        reviewType: isProduct ? ReviewType.product : ReviewType.vendor,
        productName: isProduct ? r['productName'] as String? : null,
      );
    }).toList();
  }
}
