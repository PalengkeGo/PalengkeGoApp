import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';

void main() {
  VendorProduct product({double? discountPercentage}) {
    return VendorProduct(
      id: 'p1',
      vendorId: 'v1',
      name: 'Pork Belly',
      description: 'Fresh pork belly',
      category: 'Meat',
      price: 200,
      imageUrl: 'pork.png',
      discountPercentage: discountPercentage,
    );
  }

  group('VendorProduct discount pricing', () {
    test('hasDiscount is false when discount is null or zero', () {
      expect(product().hasDiscount, isFalse);
      expect(product(discountPercentage: 0).hasDiscount, isFalse);
    });

    test(
      'discountedPrice returns original price when no discount is active',
      () {
        expect(product().discountedPrice, 200);
        expect(product(discountPercentage: 0).discountedPrice, 200);
      },
    );

    test('discountedPrice applies percentage discount', () {
      expect(product(discountPercentage: 25).discountedPrice, 150);
      expect(product(discountPercentage: 10).discountedPrice, 180);
    });
  });
}
