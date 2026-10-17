import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/navigation/app_router.dart';
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
import 'package:palengkego/features/orders/presentation/widgets/floating_order_progress.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MarketOrder _order(String id, String vendorName) => MarketOrder(
  id: id,
  vendorName: vendorName,
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
      productName: 'Carrots',
      quantity: 1,
      unitPrice: 50,
      unit: 'kg',
    ),
  ],
);

Widget _buildWidget(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: Scaffold(body: Stack(children: [FloatingOrderProgress()])),
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
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('FloatingOrderProgress', () {
    testWidgets('hides when there are no active orders', (tester) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      // All seeded orders are completed → no active orders.
      store.orders.addAll([
        _order(
          '#1',
          'Aling Nena Vegetables',
        ).copyWith(status: OrderStatus.completed),
      ]);

      await tester.pumpWidget(_buildWidget(container));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('active_orders_chat_head')), findsNothing);
      expect(find.text('Aling Nena Vegetables'), findsNothing);
    });

    testWidgets('single-order chat head opens the active order tray', (tester) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1', 'Aling Nena Vegetables'));

      await tester.pumpWidget(_buildWidget(container));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('active_orders_chat_head')), findsOneWidget);
      await tester.tap(find.byKey(const Key('active_orders_chat_head')));
      await tester.pumpAndSettle();

      expect(find.text('Aling Nena Vegetables'), findsOneWidget);
      expect(find.textContaining('Pending'), findsOneWidget);
    });

    testWidgets('chat head follows drag and docks to the nearest edge', (tester) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1', 'Aling Nena Vegetables'));

      await tester.pumpWidget(_buildWidget(container));
      await tester.pumpAndSettle();
      final head = find.byKey(const Key('active_orders_chat_head'));
      final before = tester.getTopLeft(head);

      await tester.drag(head, const Offset(-80, 60));
      await tester.pumpAndSettle();

      final after = tester.getTopLeft(head);
      final bounds = tester.getSize(
        find.ancestor(of: head, matching: find.byType(Stack)).last,
      );
      expect(after.dx, closeTo(bounds.width - 66, 1));
      expect(after.dy, greaterThan(before.dy));
      expect(after.dy, lessThanOrEqualTo(before.dy + 60));
    });

    testWidgets('hides single-order pill when active order is cancelled', (
      tester,
    ) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.add(_order('#1', 'Aling Nena Vegetables'));

      await tester.pumpWidget(_buildWidget(container));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('active_orders_chat_head')));
      await tester.pumpAndSettle();
      expect(find.text('Aling Nena Vegetables'), findsOneWidget);

      await container
          .read(orderServiceProvider.notifier)
          .cancelOrder('#1', now: DateTime.now());

      await tester.pumpAndSettle();

      expect(find.text('Aling Nena Vegetables'), findsNothing);
      expect(find.byKey(const Key('active_orders_chat_head')), findsNothing);
    });

    testWidgets(
      'shows a chat head with the active-order count',
      (tester) async {
        final store = SharedOrderStore();
        final container = _buildContainer(store: store);
        store.orders.addAll([
          _order('#1', 'Diosa Fruit Stand'),
          _order('#2', "Paul's Meat Shop"),
        ]);

        await tester.pumpWidget(_buildWidget(container));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('active_orders_chat_head')), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Diosa Fruit Stand'), findsNothing);
        expect(find.text("Paul's Meat Shop"), findsNothing);
      },
    );

    testWidgets(
      'tapping chat head opens tray listing all active orders',
      (tester) async {
        final store = SharedOrderStore();
        final container = _buildContainer(store: store);
        store.orders.addAll([
          _order('#1', 'Diosa Fruit Stand'),
          _order('#2', "Paul's Meat Shop"),
        ]);

        await tester.pumpWidget(_buildWidget(container));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('active_orders_chat_head')));
        await tester.pumpAndSettle();

        // Both vendor names appear in the tray
        expect(find.text('Diosa Fruit Stand'), findsOneWidget);
        expect(find.text("Paul's Meat Shop"), findsOneWidget);
        // A View button for each order
        expect(find.text('View'), findsNWidgets(2));
      },
    );

    testWidgets(
      'tray shows Cancel buttons when orders are within the cancel window',
      (tester) async {
        final store = SharedOrderStore();
        final container = _buildContainer(store: store);
        store.orders.addAll([
          _order('#1', 'Diosa Fruit Stand'),
          _order('#2', "Paul's Meat Shop"),
        ]);

        await tester.pumpWidget(_buildWidget(container));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('active_orders_chat_head')));
        await tester.pumpAndSettle();

        // Both orders placed right now → within 2-min window
        expect(find.text('Cancel'), findsWidgets);
      },
    );

    testWidgets('tray hides Cancel buttons when cancel window has passed', (
      tester,
    ) async {
      final store = SharedOrderStore();
      final container = _buildContainer(store: store);
      store.orders.addAll([
        _order('#1', 'Diosa Fruit Stand').copyWith(
          placedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
        _order('#2', "Paul's Meat Shop").copyWith(
          placedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      ]);

      await tester.pumpWidget(_buildWidget(container));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('active_orders_chat_head')));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsNothing);
    });
  });
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AppUser? build() => MockUsers.customer;
}
