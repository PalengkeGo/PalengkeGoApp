import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_policy.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';

void main() {
  group('deductStock (T5.1/T5.2)', () {
    test('kg products keep exact fractional deducts', () {
      expect(
        deductStock(stockQuantity: 2.0, requestedQuantity: 0.25, unit: 'kg'),
        1.75,
      );
      expect(
        deductStock(stockQuantity: 1.0, requestedQuantity: 0.5, unit: 'kg'),
        0.5,
      );
      expect(
        deductStock(stockQuantity: 5.0, requestedQuantity: 1.75, unit: 'kg'),
        3.25,
      );
    });

    test('pc products require whole numbers and deduct exactly', () {
      expect(
        deductStock(stockQuantity: 10.0, requestedQuantity: 3.0, unit: 'pc'),
        7.0,
      );
      expect(
        deductStock(stockQuantity: 10.0, requestedQuantity: 1.0, unit: 'pc'),
        9.0,
      );
    });

    test('fractional pieces throw invalidQuantity', () {
      expect(
        () => deductStock(
          stockQuantity: 10.0,
          requestedQuantity: 2.5,
          unit: 'pc',
          productName: 'Bangus',
        ),
        throwsA(
          isA<OrderFailure>().having(
            (e) => e.type,
            'type',
            OrderFailureType.invalidQuantity,
          ),
        ),
      );
    });

    test('requesting more than on-hand stock throws outOfStock', () {
      expect(
        () => deductStock(
          stockQuantity: 1.0,
          requestedQuantity: 1.5,
          unit: 'kg',
          productName: 'Carrots',
        ),
        throwsA(
          isA<OrderFailure>()
              .having((e) => e.type, 'type', OrderFailureType.outOfStock)
              .having((e) => e.message, 'message', contains('Carrots')),
        ),
      );
    });

    test('zero or negative quantities throw invalidQuantity', () {
      expect(
        () =>
            deductStock(stockQuantity: 5.0, requestedQuantity: 0.0, unit: 'kg'),
        throwsA(isA<OrderFailure>()),
      );
      expect(
        () => deductStock(
          stockQuantity: 5.0,
          requestedQuantity: -1.0,
          unit: 'pc',
        ),
        throwsA(isA<OrderFailure>()),
      );
    });
  });

  group('OrderStatusPolicy transition graph (T5.3)', () {
    test('legal transitions are accepted', () {
      expect(
        OrderStatus.pending.canTransitionTo(OrderStatus.confirmed),
        isTrue,
      );
      expect(
        OrderStatus.pending.canTransitionTo(OrderStatus.preparing),
        isTrue,
      );
      expect(OrderStatus.pending.canTransitionTo(OrderStatus.rejected), isTrue);
      expect(
        OrderStatus.pending.canTransitionTo(OrderStatus.cancelled),
        isTrue,
      );
      expect(
        OrderStatus.confirmed.canTransitionTo(OrderStatus.preparing),
        isTrue,
      );
      expect(OrderStatus.preparing.canTransitionTo(OrderStatus.ready), isTrue);
      expect(
        OrderStatus.preparing.canTransitionTo(OrderStatus.cancelled),
        isTrue,
      );
      expect(OrderStatus.ready.canTransitionTo(OrderStatus.completed), isTrue);
      expect(
        OrderStatus.ready.canTransitionTo(OrderStatus.outForDelivery),
        isTrue,
      );
      expect(
        OrderStatus.outForDelivery.canTransitionTo(OrderStatus.completed),
        isTrue,
      );
    });

    test('illegal transitions are rejected', () {
      expect(
        OrderStatus.pending.canTransitionTo(OrderStatus.completed),
        isFalse,
      );
      expect(OrderStatus.pending.canTransitionTo(OrderStatus.ready), isFalse);
      expect(
        OrderStatus.confirmed.canTransitionTo(OrderStatus.completed),
        isFalse,
      );
      expect(
        OrderStatus.preparing.canTransitionTo(OrderStatus.completed),
        isFalse,
      );
      expect(OrderStatus.ready.canTransitionTo(OrderStatus.cancelled), isFalse);
      expect(OrderStatus.confirmed.canTransitionTo(OrderStatus.ready), isFalse);
    });

    test('terminal states are immutable', () {
      for (final terminal in [
        OrderStatus.completed,
        OrderStatus.cancelled,
        OrderStatus.rejected,
      ]) {
        expect(terminal.isTerminal, isTrue);
        for (final target in OrderStatus.values) {
          expect(terminal.canTransitionTo(target), isFalse);
        }
      }
    });

    test('non-terminal states are not terminal', () {
      for (final active in [
        OrderStatus.pending,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.outForDelivery,
      ]) {
        expect(active.isTerminal, isFalse);
      }
    });
  });
}
