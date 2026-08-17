import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/market/domain/market_product.dart';

void main() {
  MarketProduct product({double? discountPercentage}) {
    return MarketProduct(
      id: 'm1',
      vendorId: 'v1',
      name: 'Sweet Mangoes',
      price: 200,
      unit: 'kg',
      description: 'Fresh mangoes',
      category: 'Fruits',
      imageUrl: '',
      discountPercentage: discountPercentage,
    );
  }

  group('MarketProduct discount pricing', () {
    test('hasDiscount is false when discount is null or zero', () {
      expect(product().hasDiscount, isFalse);
      expect(product(discountPercentage: 0).hasDiscount, isFalse);
    });

    test('discountedPrice applies percentage discount', () {
      expect(product(discountPercentage: 25).discountedPrice, 150);
      expect(product(discountPercentage: 10).discountedPrice, 180);
    });

    test('fromMap and toMap preserve discount and stock fields', () {
      final mapped = MarketProduct.fromMap({
        'id': 'm2',
        'vendorId': 'v2',
        'name': 'Bangus',
        'price': 120,
        'unit': 'pc',
        'description': 'Fresh bangus',
        'category': 'Fish',
        'imageUrl': 'bangus.png',
        'stockQuantity': 6,
        'discountPercentage': 15,
      });

      expect(mapped.stockQuantity, 6);
      expect(mapped.discountPercentage, 15);
      expect(mapped.discountedPrice, 102);
      expect(mapped.toMap()['stockQuantity'], 6);
      expect(mapped.toMap()['discountPercentage'], 15);
    });
  });
}
