import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/market/data/mock_market_repository.dart';

void main() {
  group('MockMarketRepository', () {
    test('returns featured vendors as typed market vendors', () async {
      final repository = MockMarketRepository();

      final vendors = await repository.getFeaturedVendors();

      expect(vendors, isNotEmpty);
      expect(vendors.first.id, 'v1');
      expect(vendors.first.name, 'Diosa Fruit Stand');
      expect(vendors.first.category, 'Fruits');
      expect(vendors.first.rating, 4.8);
    });

    test('filters vendors by category', () async {
      final repository = MockMarketRepository();

      final vendors = await repository.getVendorsByCategory('Fish');

      expect(vendors, isNotEmpty);
      for (final vendor in vendors) {
        final products = await repository.getProductsForVendor(vendor.id);
        final matches =
            vendor.category.toLowerCase().contains('fish') ||
            products.any(
              (product) => product.category.toLowerCase().contains('fish'),
            );
        expect(matches, isTrue);
      }
    });

    test('all category returns every featured vendor', () async {
      final repository = MockMarketRepository();

      final allVendors = await repository.getVendorsByCategory('All');
      final featuredVendors = await repository.getFeaturedVendors();

      expect(allVendors.length, featuredVendors.length);
    });

    test('returns products for a vendor', () async {
      final repository = MockMarketRepository();

      final products = await repository.getProductsForVendor('v1');

      expect(products, isNotEmpty);
      expect(products.every((product) => product.vendorId == 'v1'), isTrue);
      expect(products.first.name, 'Sweet Mangoes');
    });

    test(
      'returns no discounted products when no active discounts exist',
      () async {
        final repository = MockMarketRepository();

        final products = await repository.getDiscountedProducts();

        expect(products, isEmpty);
      },
    );

    test('returns every vendor product for product search', () async {
      final repository = MockMarketRepository();

      final products = await repository.getAllProducts();

      expect(products, isNotEmpty);
      expect(
        products.map((product) => product.vendorId).toSet().length,
        greaterThan(1),
      );
    });
  });
}
