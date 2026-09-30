import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/features/home/application/announcement_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/application/license_renewal_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_orders_screen.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_home.dart';

class _Orders extends VendorOrdersNotifier {
  _Orders(this.load);
  final Future<List<MarketOrder>> Function() load;
  @override
  Future<List<MarketOrder>> build() => load();
}

class _Stall extends VendorStallNotifier {
  @override
  VendorStall build() => const VendorStall(
    stallId: 'test',
    ownerUid: 'owner',
    name: 'Test Stall',
    description: '',
    category: 'Fruits',
    location: 'Market',
    bannerImage: 'assets/images/ncpm-onboarding.jpg',
  );
}

void main() {
  for (final screen in ['dashboard', 'pending', 'history', 'error']) {
    testWidgets('$screen can pull to refresh and waits for incoming orders', (
      tester,
    ) async {
      final refreshed = Completer<List<MarketOrder>>();
      var requests = 0;
      final notifications = NotificationService(isTest: true);
      addTearDown(notifications.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorOrdersProvider.overrideWith(
              () => _Orders(() async {
                requests++;
                if (requests > 1) return refreshed.future;
                if (screen == 'error') throw StateError('Offline');
                return [];
              }),
            ),
            vendorStallProvider.overrideWith(_Stall.new),
            computedLicenseStatusProvider.overrideWithValue(
              LicenseStatus.active,
            ),
            activeAnnouncementsProvider.overrideWith((ref) async => []),
            notificationServiceProvider.overrideWithValue(notifications),
          ],
          child: MaterialApp(
            home: screen == 'dashboard'
                ? Scaffold(
                    body: VendorDashboardHome(
                      isStallOpen: true,
                      onToggleStallOpen: (_) {},
                      onViewOrders: () {},
                      onStartPreparing: () {},
                    ),
                  )
                : VendorOrdersScreen(
                    initialTabIndex: screen == 'history' ? 1 : 0,
                  ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = screen == 'dashboard'
          ? find.byType(SingleChildScrollView).first
          : find.byType(CustomScrollView).first;
      await tester.drag(scroll, const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(requests, 2);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      refreshed.complete([
        MarketOrder(
          id: 'fresh-order',
          vendorName: 'Test Stall',
          vendorImage: '',
          status: screen == 'history'
              ? OrderStatus.completed
              : OrderStatus.pending,
          paymentStatus: PaymentStatus.pending,
          fulfillmentMethod: FulfillmentMethod.pickup,
          placedAt: DateTime.now(),
          deliveryFee: 0,
          serviceFee: 0,
          items: const [],
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Order fresh-order'), findsOneWidget);
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
