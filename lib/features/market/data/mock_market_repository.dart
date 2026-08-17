import 'package:palengkego/core/mock/mock_data.dart';
import 'package:palengkego/features/market/domain/market_repository.dart';
import 'package:palengkego/features/market/domain/market_product.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';

class MockMarketRepository implements MarketRepository {
  Future<void> _simulateDelay() async {}

  @override
  Future<List<MarketVendor>> getFeaturedVendors() async {
    await _simulateDelay();
    return MockDataService.featuredVendors
        .map(MarketVendor.fromMap)
        .toList(growable: false);
  }

  @override
  Future<List<MarketVendor>> getVendorsByCategory(String category) async {
    await _simulateDelay();
    final vendors = await getFeaturedVendors();

    if (category == 'All') {
      return vendors;
    }

    // Await all product queries
    final List<MarketVendor> filtered = [];
    for (var vendor in vendors) {
      bool isMatch = false;

      // Check category mapping
      if (vendor.category == category) {
        isMatch = true;
      } else if (category == 'Maritatas' || category == 'Sari-Sari') {
        final lowerVendorCat = vendor.category.toLowerCase();
        if (lowerVendorCat.contains('rice') ||
            lowerVendorCat.contains('grains') ||
            lowerVendorCat.contains('spice') ||
            lowerVendorCat.contains('condiment')) {
          isMatch = true;
        }
      }

      // If stall category didn't match, check products
      if (!isMatch) {
        final products = await getProductsForVendor(vendor.id);
        if (products.any((p) {
          final lowerProdCat = p.category.toLowerCase();
          if (lowerProdCat.contains(category.toLowerCase())) return true;

          if (category == 'Maritatas' || category == 'Sari-Sari') {
            if (lowerProdCat.contains('rice') ||
                lowerProdCat.contains('grains') ||
                lowerProdCat.contains('spice') ||
                lowerProdCat.contains('condiment')) {
              return true;
            }
          }
          return false;
        })) {
          isMatch = true;
        }
      }

      if (isMatch) filtered.add(vendor);
    }
    return filtered;
  }

  @override
  Future<List<MarketProduct>> getProductsForVendor(String vendorId) async {
    await _simulateDelay();
    return MockDataService.getProductsForVendor(
      vendorId,
    ).map(MarketProduct.fromMap).toList(growable: false);
  }

  @override
  Future<List<MarketProduct>> getDiscountedProducts() async {
    await _simulateDelay();
    return MockDataService.getDiscountedProducts()
        .map(MarketProduct.fromMap)
        .toList(growable: false);
  }

  @override
  Future<List<MarketProduct>> getAllProducts() async {
    await _simulateDelay();
    final vendors = await getFeaturedVendors();

    final List<MarketProduct> allProducts = [];
    for (var v in vendors) {
      final products = await getProductsForVendor(v.id);
      allProducts.addAll(products);
    }
    return allProducts;
  }
}
