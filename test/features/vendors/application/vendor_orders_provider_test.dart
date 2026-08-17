import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/data/mock_order_repository.dart';
import 'package:palengkego/features/orders/data/shared_order_store.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MarketOrder _order(
  String id, {
  OrderStatus status = OrderStatus.pending,
  DateTime? placedAt,
}) {
  return MarketOrder(
    id: id,
    vendorName: 'Diosa Fruit Stand',
    vendorImage: '',
    status: status,
    paymentStatus: PaymentStatus.pending,
    fulfillmentMethod: FulfillmentMethod.pickup,
    placedAt: placedAt ?? DateTime.now(),
    deliveryFee: 0,
    serviceFee: 15,
    items: const [
      OrderLineItem(
        productId: 'p1',
        productName: 'Pineapple',
        quantity: 1,
        unitPrice: 55,
        unit: 'pc',
      ),
    ],
  );
}

MarketOrder _otherVendorOrder(String id, {DateTime? placedAt}) {
  return _order(
    id,
    placedAt: placedAt,
  ).copyWith(vendorName: 'Aling Nena Vegetables');
}

ProviderContainer _buildContainer({SharedOrderStore? store}) {
  final container = ProviderContainer(
    overrides: [
      orderRepositoryProvider.overrideWithValue(
        MockOrderRepository(store: store),
      ),
      authProvider.overrideWith(_TestAuthNotifier.new),
      notificationServiceProvider.overrideWithValue(
        NotificationService(isTest: true, orderStore: store),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Reads [vendorOrdersProvider], first ensuring [orderServiceProvider] is
/// settled.
///
/// Workaround for a Riverpod 3.x quirk: [VendorOrdersNotifier.build] calls
/// `ref.watch(orderServiceProvider)`. If that dependency is still building
/// (fresh container, or invalidated in the same turn as `vendorOrdersProvider`
/// via `invalidateSelf`), awaiting the `.future` of the dependent provider can
/// never resolve. Draining the watched source provider first lets the rebuild
/// complete.
Future<List<MarketOrder>> _readVendorOrders(ProviderContainer container) async {
  await container.read(orderServiceProvider.future);
  return container.read(vendorOrdersProvider.future);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('VendorOrdersNotifier', () {
    test('loads only the current vendor orders from the repository', () async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      final now = DateTime.now();
      store.orders.addAll([
        _order('#1', status: OrderStatus.completed, placedAt: now),
        _order('#2', placedAt: now.add(const Duration(seconds: 5))),
        _otherVendorOrder('#3', placedAt: now.add(const Duration(seconds: 10))),
      ]);

      final orders = await _readVendorOrders(container);

      expect(orders, hasLength(2));
      expect(orders.map((o) => o.id), ['#2', '#1']);
      expect(orders.every((o) => o.vendorName == 'Diosa Fruit Stand'), isTrue);
    });

    test('acceptOrder marks a pending order as preparing', () async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1'));

      await _readVendorOrders(container);
      await container.read(vendorOrdersProvider.notifier).acceptOrder('#1');

      final orders = await _readVendorOrders(container);
      expect(orders.single.status, OrderStatus.preparing);
    });

    test('rejectOrder cancels a pending order', () async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1'));

      await _readVendorOrders(container);
      await container.read(vendorOrdersProvider.notifier).rejectOrder('#1');

      final orders = await _readVendorOrders(container);
      expect(orders.single.status, OrderStatus.cancelled);
    });

    test('markOrderReady marks an order as ready', () async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1', status: OrderStatus.preparing));

      await _readVendorOrders(container);
      await container.read(vendorOrdersProvider.notifier).markOrderReady('#1');

      final orders = await _readVendorOrders(container);
      expect(orders.single.status, OrderStatus.ready);
    });

    test('completeOrder marks an order completed and paid', () async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1', status: OrderStatus.ready));

      await _readVendorOrders(container);
      await container.read(vendorOrdersProvider.notifier).completeOrder('#1');

      final orders = await _readVendorOrders(container);
      expect(orders.single.status, OrderStatus.completed);
      expect(orders.single.paymentStatus, PaymentStatus.paid);
    });

    test(
      'completeOrder rejects a pending order with a typed failure',
      () async {
        final store = SharedOrderStore();
        final container = _buildContainer(store: store);
        store.orders.add(_order('#1'));

        await _readVendorOrders(container);
        await expectLater(
          container.read(vendorOrdersProvider.notifier).completeOrder('#1'),
          throwsA(
            isA<OrderFailure>().having(
              (e) => e.type,
              'type',
              OrderFailureType.illegalStatusTransition,
            ),
          ),
        );

        final orders = await _readVendorOrders(container);
        expect(orders.single.status, OrderStatus.pending);
      },
    );
  });
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AppUser? build() => MockUsers.vendor;
}
