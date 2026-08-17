import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/data/mock_order_repository.dart';
import 'package:palengkego/features/orders/data/shared_order_store.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:palengkego/features/orders/presentation/pages/order_details_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MarketOrder _order(String id) => MarketOrder(
  id: id,
  vendorName: 'Diosa Fruit Stand',
  vendorImage: '',
  status: OrderStatus.pending,
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

Widget _buildWidget(ProviderContainer container, MarketOrder order) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      scaffoldMessengerKey: AppServices.scaffoldMessengerKey,
      home: OrderDetailsScreen(order: order),
      routes: {AppRoutes.main: (_) => const Scaffold()},
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
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('OrderDetailsScreen', () {
    testWidgets('cancel confirmation updates the order status to cancelled', (
      tester,
    ) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1'));

      await tester.pumpWidget(_buildWidget(container, _order('#1')));
      await tester.pumpAndSettle();

      // Order summary visible
      expect(find.text('Order ##1'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.textContaining('Cancel Order'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('Cancel Order'));
      await tester.pump();
      await tester.tap(find.text('Yes, Cancel'));
      await tester.pumpAndSettle();

      final orders = await container.read(orderServiceProvider.future);
      expect(
        orders.firstWhere((item) => item.id == '#1').status,
        OrderStatus.cancelled,
      );
      expect(find.text('1 order(s) cancelled successfully.'), findsOneWidget);
      expect(find.textContaining('Cancel Order'), findsNothing);
    });

    testWidgets('declining the cancel dialog keeps the order pending', (
      tester,
    ) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1'));

      await tester.pumpWidget(_buildWidget(container, _order('#1')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('Cancel Order'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('Cancel Order'));
      await tester.pump();
      await tester.tap(find.text('No, Keep It'));
      await tester.pumpAndSettle();

      final orders = await container.read(orderServiceProvider.future);
      expect(
        orders.firstWhere((item) => item.id == '#1').status,
        OrderStatus.pending,
      );
      expect(find.text('Order ##1'), findsOneWidget);
    });

    testWidgets('status timeline follows live vendor status updates', (
      tester,
    ) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1'));

      await tester.pumpWidget(_buildWidget(container, _order('#1')));
      await tester.pumpAndSettle();

      expect(find.text('Stall Holder Confirmation'), findsOneWidget);
      expect(find.text('Preparing'), findsOneWidget);
      expect(find.text('Waiting for stall holder confirmation'), findsWidgets);

      await container
          .read(orderServiceProvider.notifier)
          .updateOrderStatus('#1', OrderStatus.preparing);
      await tester.pumpAndSettle();

      expect(find.text('Preparing'), findsOneWidget);
      expect(find.text('Stall Holder is preparing your items'), findsWidgets);
    });
  });
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AppUser? build() => MockUsers.customer;
}
