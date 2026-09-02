import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/orders/data/mock_order_repository.dart';
import 'package:palengkego/features/orders/data/shared_order_store.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';

/// Customer-requested refund lifecycle against the mock repository. Locks the
/// state machine the UI depends on: paid → refundRequested → (approve → refunded
/// | decline → paid). No money is moved client-side.
void main() {
  late MockOrderRepository repo;
  late MarketOrder paid;

  setUp(() {
    final store = SharedOrderStore();
    repo = MockOrderRepository(store: store);
    paid = MarketOrder(
      id: 'ord-refund-1',
      customerUid: 'cust-1',
      vendorName: 'Diosa Fruit Stand',
      vendorImage: '',
      status: OrderStatus.completed,
      paymentStatus: PaymentStatus.paid,
      paymentMethod: 'gcash',
      fulfillmentMethod: FulfillmentMethod.delivery,
      placedAt: DateTime(2026, 8, 1, 10),
      items: const [],
      deliveryFee: 49,
      serviceFee: 15,
    );
    store.orders.add(paid);
  });

  test('a paid order becomes refundRequested with the customer reason', () async {
    await repo.requestRefund('ord-refund-1', reason: 'Item not fresh');

    final o = (await repo.getOrdersForCustomer('cust-1')).single;
    expect(o.paymentStatus, PaymentStatus.refundRequested);
    expect(o.refundRequestReason, 'Item not fresh');
    expect(o.refundRequestedAt, isNotNull);
  });

  test('a non-paid order cannot request a refund', () async {
    final store = SharedOrderStore();
    final r = MockOrderRepository(store: store);
    final pending = paid.copyWith(
      id: 'ord-nope',
      paymentStatus: PaymentStatus.pending,
    );
    store.orders.add(pending);

    expect(
      () => r.requestRefund('ord-nope'),
      throwsA(isA<OrderFailure>()),
    );
  });

  test('approving a request refunds the order in full', () async {
    await repo.requestRefund('ord-refund-1', reason: 'Wrong item');
    await repo.processRefundRequest('ord-refund-1', approve: true);

    final o = (await repo.getOrdersForCustomer('cust-1')).single;
    expect(o.paymentStatus, PaymentStatus.refunded);
    expect(o.refundedAmount, moreOrLessEquals(o.total, epsilon: 0.001));
    expect(o.refundId, isNotNull);
  });

  test('declining a request returns the order to paid', () async {
    await repo.requestRefund('ord-refund-1', reason: 'Changed mind');
    await repo.processRefundRequest('ord-refund-1', approve: false);

    final o = (await repo.getOrdersForCustomer('cust-1')).single;
    expect(o.paymentStatus, PaymentStatus.paid);
    expect(o.refundRequestReason, isNull);
  });

  test('processing without a pending request throws', () async {
    expect(
      () => repo.processRefundRequest('ord-refund-1', approve: true),
      throwsA(isA<OrderFailure>()),
    );
  });
}