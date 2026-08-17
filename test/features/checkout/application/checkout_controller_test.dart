import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/checkout/application/checkout_controller.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_repository.dart';
import 'package:palengkego/features/orders/domain/order_status_history.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cartItem = CartItem(
    productId: 'p1',
    vendorName: 'Diosa Fruit Stand',
    productName: 'Mango',
    price: 120.0,
    image: '',
  );

  Future<ProviderContainer> containerWith({
    required _FakeOrderRepository orders,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => _CustomerAuthNotifier()),
        orderRepositoryProvider.overrideWithValue(orders),
      ],
    );
  }

  group('delivery / priority toggles', () {
    testWidgets('defaults to delivery with no priority fee', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = await containerWith(orders: _FakeOrderRepository());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            scaffoldMessengerKey: AppServices.scaffoldMessengerKey,
            home: Scaffold(
              body: _ControllerHarness(onCreated: (_) {}),
            ),
          ),
        ),
      );

      expect(container.read(checkoutProvider).deliveryMethod, 0);
      expect(container.read(checkoutProvider).isPriority, isFalse);
      expect(container.read(checkoutProvider).priorityFee, 0.0);
    });

    testWidgets('pickup never charges the priority fee', (tester) async {
      SharedPreferences.setMockInitialValues({});
      late CheckoutController controller;
      final container = await containerWith(orders: _FakeOrderRepository());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            scaffoldMessengerKey: AppServices.scaffoldMessengerKey,
            home: Scaffold(
              body: _ControllerHarness(onCreated: (c) => controller = c),
            ),
          ),
        ),
      );

      controller.setDeliveryMethod(1);
      controller.setPriority(true);

      expect(container.read(checkoutProvider).deliveryMethod, 1);
      expect(container.read(checkoutProvider).priorityFee, 0.0);
    });

    testWidgets('priority fee applies only for delivery', (tester) async {
      SharedPreferences.setMockInitialValues({});
      late CheckoutController controller;
      final container = await containerWith(orders: _FakeOrderRepository());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            scaffoldMessengerKey: AppServices.scaffoldMessengerKey,
            home: Scaffold(
              body: _ControllerHarness(onCreated: (c) => controller = c),
            ),
          ),
        ),
      );

      var notifications = 0;
      container.listen(checkoutProvider, (_, _) => notifications++);

      controller.setDeliveryMethod(0);
      controller.setPriority(true);

      expect(container.read(checkoutProvider).isPriority, isTrue);
      expect(container.read(checkoutProvider).priorityFee, FeeConfig.priorityFee);
      expect(notifications, 2);
    });
  });

  group('vendor notes', () {
    testWidgets('keeps one controller per vendor and strips blank notes', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      late CheckoutController controller;
      final container = await containerWith(orders: _FakeOrderRepository());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            scaffoldMessengerKey: AppServices.scaffoldMessengerKey,
            home: Scaffold(
              body: _ControllerHarness(onCreated: (c) => controller = c),
            ),
          ),
        ),
      );

      final vendorA = controller.notesControllerFor('Vendor A');
      final vendorADuplicate = controller.notesControllerFor('Vendor A');
      final vendorB = controller.notesControllerFor('Vendor B');

      expect(vendorA, same(vendorADuplicate));
      expect(vendorB, isNot(same(vendorA)));
    });
  });

  group('CheckoutController.placeOrder', () {
    testWidgets('groups a non-empty note and passes pickup/priority flags', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final orders = _FakeOrderRepository();
      final container = await containerWith(orders: orders);
      addTearDown(container.dispose);
      late CheckoutController controller;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            scaffoldMessengerKey: AppServices.scaffoldMessengerKey,
            home: Scaffold(
              body: _ControllerHarness(onCreated: (c) => controller = c),
            ),
          ),
        ),
      );

      controller.setDeliveryMethod(0);
      controller.setPriority(true);
      controller.notesControllerFor('Diosa Fruit Stand').text = 'No saging';

      final created = await controller.placeOrder(selectedItems: [cartItem]);

      expect(created, [orders.returnedOrder]);
      final call = orders.lastPlaceOrderCall!;
      expect(call.isPickup, isFalse);
      expect(call.isPriority, isTrue);
      expect(call.priorityFee, FeeConfig.priorityFee);
      expect(call.vendorNotes, {'Diosa Fruit Stand': 'No saging'});
      expect(container.read(checkoutProvider).placingOrder, isFalse);
    });

    testWidgets('blank vendor notes are dropped from the placed order', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final orders = _FakeOrderRepository();
      final container = await containerWith(orders: orders);
      addTearDown(container.dispose);
      late CheckoutController controller;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            scaffoldMessengerKey: AppServices.scaffoldMessengerKey,
            home: Scaffold(
              body: _ControllerHarness(onCreated: (c) => controller = c),
            ),
          ),
        ),
      );

      controller.notesControllerFor('Diosa Fruit Stand').text = '   ';

      final created = await controller.placeOrder(selectedItems: [cartItem]);

      expect(created, isNotNull);
      expect(orders.lastPlaceOrderCall!.vendorNotes, isNull);
    });

    testWidgets('a typed order failure aborts without clearing the cart', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final orders = _FakeOrderRepository(
        error: const OrderFailure(
          OrderFailureType.outOfStock,
          message: 'Mango is out of stock.',
        ),
      );
      final container = await containerWith(orders: orders);
      addTearDown(container.dispose);
      late CheckoutController controller;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            scaffoldMessengerKey: AppServices.scaffoldMessengerKey,
            home: Scaffold(
              body: _ControllerHarness(onCreated: (c) => controller = c),
            ),
          ),
        ),
      );

      final created = await controller.placeOrder(selectedItems: [cartItem]);

      expect(created, isNull);
      expect(container.read(checkoutProvider).placingOrder, isFalse);
      await tester.pump();
      await tester.pump();
      expect(find.text('Mango is out of stock.'), findsOneWidget);

      // Let the error snackbar timer finish so no timers are pending.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });
}

class _CustomerAuthNotifier extends AuthNotifier {
  @override
  AppUser? build() {
    return const AppUser(
      uid: 'cust-1',
      email: 'customer@example.com',
      displayName: 'Customer',
      role: UserRole.customer,
    );
  }
}

class _ControllerHarness extends ConsumerStatefulWidget {
  const _ControllerHarness({required this.onCreated});

  final void Function(CheckoutController controller) onCreated;

  @override
  ConsumerState<_ControllerHarness> createState() => _ControllerHarnessState();
}

class _ControllerHarnessState extends ConsumerState<_ControllerHarness> {
  @override
  void initState() {
    super.initState();
    // The notifier is provider-owned; the harness merely surfaces it to the test.
    widget.onCreated(ref.read(checkoutProvider.notifier));
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository({this.error});

  final OrderFailure? error;
  final MarketOrder returnedOrder = MarketOrder(
    id: 'ord-test-1',
    customerUid: 'cust-1',
    vendorName: 'Diosa Fruit Stand',
    vendorImage: '',
    status: OrderStatus.pending,
    paymentStatus: PaymentStatus.pending,
    fulfillmentMethod: FulfillmentMethod.delivery,
    placedAt: DateTime(2026, 8, 1, 10),
    items: [],
    deliveryFee: 0,
    serviceFee: 0,
  );

  ({
    bool isPickup,
    bool isPriority,
    double priorityFee,
    Map<String, String>? vendorNotes,
  })?
  lastPlaceOrderCall;

  @override
  Future<List<MarketOrder>> placeOrders({
    required Map<String, (String vendorImage, List<OrderLineItem> items)>
    groupedItems,
    required bool isPickup,
    String customerUid = '',
    String customerName = 'Customer',
    Map<String, String>? vendorNotes,
    String? deliveryAddress,
    bool isPriority = false,
    double priorityFee = 0.0,
    String paymentMethod = 'cod',
  }) async {
    lastPlaceOrderCall = (
      isPickup: isPickup,
      isPriority: isPriority,
      priorityFee: priorityFee,
      vendorNotes: vendorNotes,
    );
    if (error != null) throw error!;
    return [returnedOrder];
  }

  @override
  Future<List<MarketOrder>> getOrdersForCustomer(String customerUid) async =>
      [];

  @override
  Future<List<MarketOrder>> getOrdersForVendor(String stallId) async => [];

  @override
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String? changedByUid,
    String? remarks,
    DateTime? estimatedReadyTime,
  }) async {}

  @override
  Future<void> cancelOrder(
    String orderId, {
    String? reason,
    DateTime? now,
  }) async {}

  @override
  Future<List<OrderStatusHistory>> getOrderHistory(String orderId) async => [];
}
