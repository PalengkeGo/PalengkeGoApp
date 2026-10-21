import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:palengkego/features/orders/presentation/widgets/tracking_map_preview.dart';

void main() {
  final order = MarketOrder(
    id: 'order',
    vendorName: 'Stall',
    vendorImage: '',
    status: OrderStatus.pending,
    paymentStatus: PaymentStatus.pending,
    fulfillmentMethod: FulfillmentMethod.delivery,
    placedAt: DateTime.now(),
    items: [],
    deliveryFee: 30,
    serviceFee: 0,
    deliveryAddress: 'Customer delivery address',
    deliveryLatitude: 13.64,
    deliveryLongitude: 123.2,
  );

  test(
    'paid wallets cannot be cancelled; unpaid wallets and COD remain eligible',
    () {
      for (final method in ['gcash', 'maya', 'paymaya']) {
        expect(order.copyWith(paymentMethod: method).canCustomerCancel, isTrue);
        expect(
          order
              .copyWith(
                paymentMethod: method,
                paymentStatus: PaymentStatus.paid,
              )
              .canCustomerCancel,
          isFalse,
        );
      }
      expect(order.canCustomerCancel, isTrue);
      expect(
        order.copyWith(status: OrderStatus.preparing).canCustomerCancel,
        isFalse,
      );
    },
  );

  testWidgets(
    'motorcycle progresses from market to saved delivery pin by status',
    (tester) async {
      // Inspect map configuration without mounting network tile layers.
      for (final entry in <OrderStatus, double?>{
        OrderStatus.pending: null,
        OrderStatus.confirmed: 0,
        OrderStatus.preparing: 0,
        OrderStatus.ready: .25,
        OrderStatus.outForDelivery: .65,
        OrderStatus.completed: 1,
        OrderStatus.cancelled: null,
        OrderStatus.rejected: null,
      }.entries) {
        late Stack stack;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final container =
                    TrackingMapPreview(
                          order: order.copyWith(status: entry.key),
                        ).build(context)
                        as Container;
                stack = (container.child! as ClipRRect).child! as Stack;
                return const SizedBox();
              },
            ),
          ),
        );
        final map = stack.children.whereType<FlutterMap>().single;
        final markers = map.children.whereType<MarkerLayer>().single.markers;
        expect(markers.length, entry.value == null ? 2 : 3);
        expect(markers.first.point.latitude, FeeConfig.deliveryOriginLat);
        expect(markers[1].point.latitude, order.deliveryLatitude);
        if (entry.value != null) {
          expect(
            markers.last.point.latitude,
            closeTo(
              FeeConfig.deliveryOriginLat +
                  (order.deliveryLatitude! - FeeConfig.deliveryOriginLat) *
                      entry.value!,
              1e-9,
            ),
          );
        }
      }
    },
  );
}
