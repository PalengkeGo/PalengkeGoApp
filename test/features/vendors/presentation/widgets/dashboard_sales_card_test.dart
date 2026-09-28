import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_sales_card.dart';

MarketOrder _testOrder({
  required String id,
  required OrderStatus status,
  double total = 150.0,
}) {
  return MarketOrder(
    id: id,
    vendorName: 'Test Stall',
    vendorImage: '',
    status: status,
    paymentStatus: PaymentStatus.paid,
    fulfillmentMethod: FulfillmentMethod.pickup,
    placedAt: DateTime.now(),
    deliveryFee: 0,
    serviceFee: 0,
    items: const [
      OrderLineItem(
        productId: 'p1',
        productName: 'Mango',
        quantity: 1,
        unitPrice: 150,
        unit: 'kg',
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DashboardSalesCard Widget Tests', () {
    testWidgets('renders Pending and Completed badges with clock and checkmark icons', (
      tester,
    ) async {
      final orders = [
        _testOrder(id: '1', status: OrderStatus.pending),
        _testOrder(id: '2', status: OrderStatus.completed, total: 250.0),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorOrdersProvider.overrideWith(
              () => _TestVendorOrdersNotifier(orders),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DashboardSalesCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check labels and counts
      expect(find.text("Today's Sales"), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('1 Order'), findsNWidgets(2)); // 1 Pending and 1 Completed
      expect(find.text('Completed'), findsOneWidget);

      // Check self-explanatory icons
      expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('tapping Pending switches to orders tab (index 1) and pending orders tab (index 0)', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          vendorOrdersProvider.overrideWith(
            () => _TestVendorOrdersNotifier([]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: DashboardSalesCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state
      expect(container.read(vendorDashboardTabIndexProvider), 0);
      expect(container.read(vendorOrdersTabIndexProvider), 0);

      // Tap Pending box
      await tester.tap(find.text('Pending'));
      await tester.pumpAndSettle();

      expect(container.read(vendorDashboardTabIndexProvider), 1);
      expect(container.read(vendorOrdersTabIndexProvider), 0);
    });

    testWidgets('tapping Completed switches to orders tab (index 1) and completed orders tab (index 1)', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          vendorOrdersProvider.overrideWith(
            () => _TestVendorOrdersNotifier([]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: DashboardSalesCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Completed box
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(container.read(vendorDashboardTabIndexProvider), 1);
      expect(container.read(vendorOrdersTabIndexProvider), 1);
    });
  });

  group('NotificationService Vendor and Announcement Tests', () {
    test('onNewOrderArrived notifies vendor in-app and deduplicates', () async {
      final service = NotificationService(isTest: true);

      expect(service.forVendor, isEmpty);

      await service.onNewOrderArrived('ord_101', 'Juan dela Cruz', 350.0);
      expect(service.forVendor.length, 1);
      expect(service.forVendor.first.title, contains('New Order Arrived!'));
      expect(service.forVendor.first.referenceId, 'ord_101');

      // Calling again with same order ID must be deduplicated
      await service.onNewOrderArrived('ord_101', 'Juan dela Cruz', 350.0);
      expect(service.forVendor.length, 1);
    });

    test('onNewAnnouncement notifies target audience and deduplicates', () async {
      final service = NotificationService(isTest: true);

      expect(service.forCustomer, isEmpty);
      expect(service.forVendor, isEmpty);

      await service.onNewAnnouncement(
        announcementId: 'mepo_ann_01',
        title: 'Scheduled Market Maintenance',
        body: 'Market will undergo maintenance this Sunday.',
        target: NotificationTarget.both,
      );

      // NotificationTarget.both is visible to both customers and vendors
      expect(service.forCustomer.length, 1);
      expect(service.forVendor.length, 1);
      expect(service.forCustomer.first.title, contains('Scheduled Market Maintenance'));

      // Calling again with same ID deduplicates
      await service.onNewAnnouncement(
        announcementId: 'mepo_ann_01',
        title: 'Scheduled Market Maintenance',
        body: 'Market will undergo maintenance this Sunday.',
        target: NotificationTarget.both,
      );
      expect(service.forCustomer.length, 1);
      expect(service.forVendor.length, 1);
    });
  });
}

class _TestVendorOrdersNotifier extends VendorOrdersNotifier {
  final List<MarketOrder> initialOrders;
  _TestVendorOrdersNotifier(this.initialOrders);

  @override
  Future<List<MarketOrder>> build() async => initialOrders;
}
