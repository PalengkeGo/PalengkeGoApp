import 'package:freezed_annotation/freezed_annotation.dart';
import 'order_line_item.dart';
import 'order_status.dart';
import 'fulfillment_method.dart';
import 'payment_status.dart';

part 'market_order.freezed.dart';
part 'market_order.g.dart';

@freezed
abstract class MarketOrder with _$MarketOrder {
  const MarketOrder._(); // allows custom methods/getters

  const factory MarketOrder({
    required String id,
    String? customerUid,
    String? stallId,
    required String vendorName,
    required String vendorImage,
    @Default('Customer') String customerName,
    required OrderStatus status,
    required PaymentStatus paymentStatus,
    @Default('cod') String paymentMethod,
    required FulfillmentMethod fulfillmentMethod,
    required DateTime placedAt,
    required List<OrderLineItem> items,
    String? deliveryAddress,
    required double deliveryFee,
    required double serviceFee,
    @Default(false) bool isPriority,
    @Default(0.0) double priorityFee,
    String? notes,
    DateTime? estimatedReadyTime,

    /// Populated when status is cancelled or rejected.
    /// Set by the vendor or system explaining why the order was not fulfilled.
    String? cancellationReason,
  }) = _MarketOrder;

  factory MarketOrder.fromJson(Map<String, dynamic> json) =>
      _$MarketOrderFromJson(json);

  double get subtotal => items.fold<double>(0, (sum, item) => sum + item.total);
  double get total => subtotal + deliveryFee + priorityFee + serviceFee;

  String get statusLabel => status.label;
  bool get isPickup => fulfillmentMethod == FulfillmentMethod.pickup;
}
