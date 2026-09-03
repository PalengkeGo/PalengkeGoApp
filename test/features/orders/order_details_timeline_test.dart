import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_details_cards.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_details_timeline.dart';

void main() {
  group('OrderDetailsTimeline', () {
    testWidgets('In-progress order has outline circles without green fill', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrderDetailsTimeline(
              currentStatus: OrderStatus.pending,
              isPickup: false,
            ),
          ),
        ),
      );

      // In-progress: "Order Placed" (completed) shows green check, "Stall Holder Confirmation" (active) has outline only
      expect(find.text('Order Placed'), findsOneWidget);
      expect(find.text('Stall Holder Confirmation'), findsOneWidget);

      // Find circle containers (24x24)
      final containers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        return c.constraints?.maxWidth == 24 && c.constraints?.maxHeight == 24;
      }).toList();

      expect(containers.isNotEmpty, isTrue);
      for (final container in containers) {
        final deco = container.decoration as BoxDecoration;
        // Should NOT have green fill (either white background with green border or gray border)
        expect(deco.color, equals(Colors.white));
      }
    });

    testWidgets('Completed order has green filled circles and check marks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrderDetailsTimeline(
              currentStatus: OrderStatus.completed,
              isPickup: false,
            ),
          ),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        return c.constraints?.maxWidth == 24 && c.constraints?.maxHeight == 24;
      }).toList();

      expect(containers.isNotEmpty, isTrue);
      for (final container in containers) {
        final deco = container.decoration as BoxDecoration;
        expect(deco.color, equals(AppTheme.primaryGreen));
      }
    });
  });

  group('OrderDetailsStatusCard Priority Badge', () {
    testWidgets('Does NOT show PRIORITY badge for standard delivery orders', (tester) async {
      final order = MarketOrder(
        id: 'ord-std-1',
        vendorName: 'Diosa Fruit Stand',
        vendorImage: '',
        customerName: 'Juan',
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
        fulfillmentMethod: FulfillmentMethod.delivery,
        placedAt: DateTime.now(),
        items: const [],
        deliveryFee: 49.0,
        serviceFee: 0.0,
        isPriority: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderDetailsStatusCard(
              order: order,
              statusDescription: 'Your order is being reviewed',
            ),
          ),
        ),
      );

      expect(find.text('PRIORITY'), findsNothing);
    });

    testWidgets('Shows PRIORITY badge when order isPriority is true', (tester) async {
      final order = MarketOrder(
        id: 'ord-prio-1',
        vendorName: 'Diosa Fruit Stand',
        vendorImage: '',
        customerName: 'Juan',
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
        fulfillmentMethod: FulfillmentMethod.delivery,
        placedAt: DateTime.now(),
        items: const [],
        deliveryFee: 49.0,
        serviceFee: 0.0,
        isPriority: true,
        priorityFee: 29.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderDetailsStatusCard(
              order: order,
              statusDescription: 'Your order is being reviewed',
            ),
          ),
        ),
      );

      expect(find.text('PRIORITY'), findsOneWidget);
    });
  });
}
