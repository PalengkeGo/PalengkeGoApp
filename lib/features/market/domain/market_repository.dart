import 'package:palengkego/features/market/domain/market_product.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';

abstract class MarketRepository {
  Future<List<MarketVendor>> getFeaturedVendors();

  Future<List<MarketVendor>> getVendorsByCategory(String category);

  Future<List<MarketProduct>> getProductsForVendor(String vendorId);

  Future<List<MarketProduct>> getDiscountedProducts();

  Future<List<MarketProduct>> getAllProducts();
}
