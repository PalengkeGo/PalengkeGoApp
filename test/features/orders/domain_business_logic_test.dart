import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';

void main() {
  // ─────────────────────────────────────────────
  // CartItem domain tests
  // ─────────────────────────────────────────────
  group('CartItem', () {
    group('total', () {
      test('calculates total as price × quantity', () {
        const item = CartItem(
          productId: 'dummy_product_id',
          vendorName: 'Aling Nena',
          productName: 'Carrots',
          price: 120,
          unit: 'kg',
          image: '',
          quantity: 2.5,
        );
        expect(item.total, 300.0);
      });

      test('total is 0 when quantity is 0', () {
        const item = CartItem(
          productId: 'dummy_product_id',
          vendorName: 'V',
          productName: 'P',
          price: 100,
          image: '',
          quantity: 0,
        );
        expect(item.total, 0.0);
      });
    });

    group('quantityLabel', () {
      test('returns "1/4 kg" for 0.25 kg', () {
        const item = CartItem(
          productId: 'dummy_product_id',
          vendorName: 'V',
          productName: 'P',
          price: 100,
          unit: 'kg',
          image: '',
          quantity: 0.25,
        );
        expect(item.quantityLabel, '1/4 kg');
      });

      test('returns "1/2 kg" for 0.5 kg', () {
        const item = CartItem(
          productId: 'dummy_product_id',
          vendorName: 'V',
          productName: 'P',
          price: 100,
          unit: 'kg',
          image: '',
          quantity: 0.5,
        );
        expect(item.quantityLabel, '1/2 kg');
      });

      test('returns "3/4 kg" for 0.75 kg', () {
        const item = CartItem(
          productId: 'dummy_product_id',
          vendorName: 'V',
          productName: 'P',
          price: 100,
          unit: 'kg',
          image: '',
          quantity: 0.75,
        );
        expect(item.quantityLabel, '3/4 kg');
      });

      test('returns whole number for 1 kg without decimal', () {
        const item = CartItem(
          productId: 'dummy_product_id',
          vendorName: 'V',
          productName: 'P',
          price: 100,
          unit: 'kg',
          image: '',
          quantity: 1.0,
        );
        expect(item.quantityLabel, '1 kg');
      });

      test(
        'returns fraction for 1.5 kg and decimal for non-standard kg quantity',
        () {
          const itemHalf = CartItem(
            productId: 'dummy_product_id',
            vendorName: 'V',
            productName: 'P',
            price: 100,
            unit: 'kg',
            image: '',
            quantity: 1.5,
          );
          expect(itemHalf.quantityLabel, '1 1/2 kg');

          const itemDecimal = CartItem(
            productId: 'dummy_product_id',
            vendorName: 'V',
            productName: 'P',
            price: 100,
            unit: 'kg',
            image: '',
            quantity: 1.3,
          );
          expect(itemDecimal.quantityLabel, '1.3 kg');
        },
      );

      test('returns piece quantity for pc unit', () {
        const item = CartItem(
          productId: 'dummy_product_id',
          vendorName: 'V',
          productName: 'Egg',
          price: 10,
          unit: 'pc',
          image: '',
          quantity: 6.0,
        );
        expect(item.quantityLabel, '6 pc');
      });

      test('does not apply kg fractions to pc unit', () {
        const item = CartItem(
          productId: 'dummy_product_id',
          vendorName: 'V',
          productName: 'Egg',
          price: 10,
          unit: 'pc',
          image: '',
          quantity: 0.5,
        );
        // 0.5 pc — should NOT return "1/2 kg" since unit is 'pc'
        expect(item.quantityLabel, '0.5 pc');
      });
    });
  });

  // ─────────────────────────────────────────────
  // OrderLineItem domain tests
  // ─────────────────────────────────────────────
  group('OrderLineItem', () {
    group('total', () {
      test('calculates total as unitPrice × quantity', () {
        const item = OrderLineItem(
          productId: 'dummy_product_id',
          productName: 'Pork Belly',
          quantity: 1.5,
          unitPrice: 200.0,
          unit: 'kg',
        );
        expect(item.total, 300.0);
      });

      test('calculates total for piece-based items', () {
        const item = OrderLineItem(
          productId: 'dummy_product_id',
          productName: 'Egg',
          quantity: 12,
          unitPrice: 10.0,
          unit: 'pc',
        );
        expect(item.total, 120.0);
      });
    });

    group('quantityLabel', () {
      test('returns "1/4 kg" for 0.25 kg', () {
        const item = OrderLineItem(
          productId: 'dummy_product_id',
          productName: 'P',
          quantity: 0.25,
          unitPrice: 100,
          unit: 'kg',
        );
        expect(item.quantityLabel, '1/4 kg');
      });

      test('returns "1/2 kg" for 0.5 kg', () {
        const item = OrderLineItem(
          productId: 'dummy_product_id',
          productName: 'P',
          quantity: 0.5,
          unitPrice: 100,
          unit: 'kg',
        );
        expect(item.quantityLabel, '1/2 kg');
      });

      test('returns "3/4 kg" for 0.75 kg', () {
        const item = OrderLineItem(
          productId: 'dummy_product_id',
          productName: 'P',
          quantity: 0.75,
          unitPrice: 100,
          unit: 'kg',
        );
        expect(item.quantityLabel, '3/4 kg');
      });

      test('returns "6 pc" for 6 pieces', () {
        const item = OrderLineItem(
          productId: 'dummy_product_id',
          productName: 'Egg',
          quantity: 6,
          unitPrice: 10,
          unit: 'pc',
        );
        expect(item.quantityLabel, '6 pc');
      });
    });
  });

  // ─────────────────────────────────────────────
  // MarketOrder totaling tests
  // ─────────────────────────────────────────────
  group('MarketOrder', () {
    MarketOrder buildOrder({
      List<OrderLineItem> items = const [],
      double deliveryFee = 0,
      double serviceFee = 0,
      FulfillmentMethod method = FulfillmentMethod.pickup,
    }) {
      return MarketOrder(
        id: 'ORD-001',
        vendorName: 'Test Vendor',
        vendorImage: '',
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
        fulfillmentMethod: method,
        placedAt: DateTime(2025, 1, 1),
        items: items,
        deliveryFee: deliveryFee,
        serviceFee: serviceFee,
      );
    }

    group('subtotal', () {
      test('is 0 for empty order', () {
        final order = buildOrder();
        expect(order.subtotal, 0.0);
      });

      test('sums all item totals correctly', () {
        final order = buildOrder(
          items: const [
            OrderLineItem(
              productId: 'dummy_product_id',
              productName: 'Mango',
              quantity: 2,
              unitPrice: 150,
            ),
            OrderLineItem(
              productId: 'dummy_product_id',
              productName: 'Bangus',
              quantity: 1,
              unitPrice: 90,
            ),
          ],
        );
        // 2 × 150 + 1 × 90 = 390
        expect(order.subtotal, 390.0);
      });

      test('handles fractional kg quantities', () {
        final order = buildOrder(
          items: const [
            OrderLineItem(
              productId: 'dummy_product_id',
              productName: 'Pork',
              quantity: 0.5,
              unitPrice: 280,
              unit: 'kg',
            ),
          ],
        );
        expect(order.subtotal, 140.0);
      });
    });

    group('total', () {
      test('adds delivery and service fees to subtotal', () {
        final order = buildOrder(
          items: const [
            OrderLineItem(
              productId: 'dummy_product_id',
              productName: 'Carrots',
              quantity: 1,
              unitPrice: 120,
            ),
          ],
          deliveryFee: 50,
          serviceFee: 15,
        );
        // 120 + 50 + 15 = 185
        expect(order.total, 185.0);
      });

      test('total equals subtotal when fees are 0', () {
        final order = buildOrder(
          items: const [
            OrderLineItem(
              productId: 'dummy_product_id',
              productName: 'Carrots',
              quantity: 1,
              unitPrice: 120,
            ),
          ],
        );
        expect(order.total, 120.0);
      });

      test('total handles multiple vendors worth of items', () {
        final order = buildOrder(
          items: const [
            OrderLineItem(
              productId: 'dummy_product_id',
              productName: 'Mango',
              quantity: 2,
              unitPrice: 150,
            ),
            OrderLineItem(
              productId: 'dummy_product_id',
              productName: 'Bangus',
              quantity: 1,
              unitPrice: 90,
            ),
            OrderLineItem(
              productId: 'dummy_product_id',
              productName: 'Pork',
              quantity: 0.5,
              unitPrice: 280,
            ),
          ],
          deliveryFee: 30,
          serviceFee: 10,
        );
        // (300 + 90 + 140) + 30 + 10 = 570
        expect(order.total, 570.0);
      });
    });

    group('isPickup', () {
      test('returns true for pickup fulfillment', () {
        final order = buildOrder(method: FulfillmentMethod.pickup);
        expect(order.isPickup, isTrue);
      });

      test('returns false for delivery fulfillment', () {
        final order = buildOrder(method: FulfillmentMethod.delivery);
        expect(order.isPickup, isFalse);
      });
    });
  });

  // ─────────────────────────────────────────────
  // VendorProduct pricing & discount tests
  // ─────────────────────────────────────────────
  group('VendorProduct', () {
    group('discountedPrice', () {
      test('returns original price when no discount', () {
        const product = VendorProduct(
          id: 'p1',
          vendorId: 'v1',
          name: 'Carrots',
          description: '',
          category: 'Vegetables',
          price: 120,
          imageUrl: '',
          stockQuantity: 10,
        );
        expect(product.discountedPrice, 120.0);
        expect(product.hasDiscount, isFalse);
      });

      test('returns original price when discount is 0', () {
        const product = VendorProduct(
          id: 'p1',
          vendorId: 'v1',
          name: 'Carrots',
          description: '',
          category: 'Vegetables',
          price: 120,
          imageUrl: '',
          stockQuantity: 10,
          discountPercentage: 0,
        );
        expect(product.discountedPrice, 120.0);
        expect(product.hasDiscount, isFalse);
      });

      test('applies 25% discount correctly', () {
        const product = VendorProduct(
          id: 'p2',
          vendorId: 'v1',
          name: 'Pork Belly',
          description: '',
          category: 'Meat',
          price: 200,
          imageUrl: '',
          stockQuantity: 5,
          discountPercentage: 25,
        );
        expect(product.discountedPrice, 150.0);
        expect(product.hasDiscount, isTrue);
      });

      test('applies 10% discount correctly', () {
        const product = VendorProduct(
          id: 'p3',
          vendorId: 'v1',
          name: 'Bangus',
          description: '',
          category: 'Seafood',
          price: 90,
          imageUrl: '',
          stockQuantity: 8,
          discountPercentage: 10,
        );
        // 90 - 9 = 81
        expect(product.discountedPrice, 81.0);
      });

      test('applies 50% discount correctly', () {
        const product = VendorProduct(
          id: 'p4',
          vendorId: 'v1',
          name: 'Clearance Item',
          description: '',
          category: 'Misc',
          price: 100,
          imageUrl: '',
          stockQuantity: 2,
          discountPercentage: 50,
        );
        expect(product.discountedPrice, 50.0);
      });

      test('applies 100% discount results in free item', () {
        const product = VendorProduct(
          id: 'p5',
          vendorId: 'v1',
          name: 'Free Sample',
          description: '',
          category: 'Misc',
          price: 100,
          imageUrl: '',
          stockQuantity: 1,
          discountPercentage: 100,
        );
        expect(product.discountedPrice, 0.0);
      });
    });
  });
}
