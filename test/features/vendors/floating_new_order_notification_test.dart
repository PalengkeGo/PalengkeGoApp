import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/features/orders/data/mock_order_repository.dart';
import 'package:palengkego/features/orders/data/shared_order_store.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';
import 'package:palengkego/features/vendors/presentation/widgets/floating_new_order_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MarketOrder _order(String id, {OrderStatus status = OrderStatus.pending}) {
  return MarketOrder(
    id: id,
    vendorName: 'Diosa Fruit Stand',
    vendorImage: '',
    status: status,
    paymentStatus: PaymentStatus.pending,
    fulfillmentMethod: FulfillmentMethod.pickup,
    placedAt: DateTime.now(),
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

Widget _buildWidget(ProviderContainer container, VoidCallback onViewOrders) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [FloatingNewOrderNotification(onViewOrders: onViewOrders)],
        ),
      ),
    ),
  );
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FloatingNewOrderNotification', () {
    testWidgets('hides the banner when there are no pending orders', (
      tester,
    ) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1', status: OrderStatus.completed));

      await tester.pumpWidget(_buildWidget(container, () {}));
      await tester.pumpAndSettle();

      expect(find.textContaining('New Order'), findsNothing);
      expect(find.text('Tap to review and accept'), findsNothing);
    });

    testWidgets('shows a single-order banner when a pending order arrives', (
      tester,
    ) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1'));

      await tester.pumpWidget(_buildWidget(container, () {}));
      await tester.pumpAndSettle();

      expect(find.text('1 New Order!'), findsOneWidget);
      expect(find.text('Tap to review and accept'), findsOneWidget);
    });

    testWidgets('shows a plural banner for multiple pending orders', (
      tester,
    ) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.addAll([_order('#1'), _order('#2')]);

      await tester.pumpWidget(_buildWidget(container, () {}));
      await tester.pumpAndSettle();

      expect(find.text('2 New Orders!'), findsOneWidget);
    });

    testWidgets('ignores non-pending orders when counting', (tester) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.addAll([
        _order('#1', status: OrderStatus.completed),
        _order('#2', status: OrderStatus.cancelled),
        _order('#3'),
      ]);

      await tester.pumpWidget(_buildWidget(container, () {}));
      await tester.pumpAndSettle();

      expect(find.text('1 New Order!'), findsOneWidget);
    });

    testWidgets('invokes onViewOrders when the banner is tapped', (
      tester,
    ) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1'));

      var tapped = false;
      await tester.pumpWidget(_buildWidget(container, () => tapped = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1 New Order!'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('hides the banner after the pending order is accepted', (
      tester,
    ) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1'));

      await tester.pumpWidget(_buildWidget(container, () {}));
      await tester.pumpAndSettle();
      expect(find.text('1 New Order!'), findsOneWidget);

      // Drive the provider work in the real async zone: awaiting these futures
      // inside the widget test's fake-async zone deadlocks once the notifier
      // invalidates itself (its build watches another invalidated notifier).
      await tester.runAsync(() async {
        await container.read(vendorOrdersProvider.future);
        await container.read(vendorOrdersProvider.notifier).acceptOrder('#1');
        // Drain the watched source provider so the vendorOrders rebuild
        // completes.
        await container.read(orderServiceProvider.future);
      });

      await tester.pumpAndSettle();

      // Note: FloatingNewOrderNotification displays the banner only while at
      // least one pending order exists; after acceptOrder the order moves to
      // `preparing` so the banner goes away.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('New Order'), findsNothing);
    });
  });
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AppUser? build() => MockUsers.vendor;
}
