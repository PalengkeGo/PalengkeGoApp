// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'market_order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MarketOrder _$MarketOrderFromJson(Map<String, dynamic> json) => _MarketOrder(
  id: json['id'] as String,
  customerUid: json['customerUid'] as String?,
  stallId: json['stallId'] as String?,
  vendorName: json['vendorName'] as String,
  vendorImage: json['vendorImage'] as String,
  customerName: json['customerName'] as String? ?? 'Customer',
  status: $enumDecode(_$OrderStatusEnumMap, json['status']),
  paymentStatus: $enumDecode(_$PaymentStatusEnumMap, json['paymentStatus']),
  paymentMethod: json['paymentMethod'] as String? ?? 'cod',
  fulfillmentMethod: $enumDecode(
    _$FulfillmentMethodEnumMap,
    json['fulfillmentMethod'],
  ),
  placedAt: DateTime.parse(json['placedAt'] as String),
  items: (json['items'] as List<dynamic>)
      .map((e) => OrderLineItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  deliveryAddress: json['deliveryAddress'] as String?,
  deliveryFee: (json['deliveryFee'] as num).toDouble(),
  serviceFee: (json['serviceFee'] as num).toDouble(),
  isPriority: json['isPriority'] as bool? ?? false,
  priorityFee: (json['priorityFee'] as num?)?.toDouble() ?? 0.0,
  notes: json['notes'] as String?,
  estimatedReadyTime: json['estimatedReadyTime'] == null
      ? null
      : DateTime.parse(json['estimatedReadyTime'] as String),
  cancellationReason: json['cancellationReason'] as String?,
  refundRequestReason: json['refundRequestReason'] as String?,
  refundRequestedAt: json['refundRequestedAt'] == null
      ? null
      : DateTime.parse(json['refundRequestedAt'] as String),
  refundedAmount: (json['refundedAmount'] as num?)?.toDouble() ?? 0.0,
  refundId: json['refundId'] as String?,
);

Map<String, dynamic> _$MarketOrderToJson(
  _MarketOrder instance,
) => <String, dynamic>{
  'id': instance.id,
  'customerUid': instance.customerUid,
  'stallId': instance.stallId,
  'vendorName': instance.vendorName,
  'vendorImage': instance.vendorImage,
  'customerName': instance.customerName,
  'status': _$OrderStatusEnumMap[instance.status]!,
  'paymentStatus': _$PaymentStatusEnumMap[instance.paymentStatus]!,
  'paymentMethod': instance.paymentMethod,
  'fulfillmentMethod': _$FulfillmentMethodEnumMap[instance.fulfillmentMethod]!,
  'placedAt': instance.placedAt.toIso8601String(),
  'items': instance.items,
  'deliveryAddress': instance.deliveryAddress,
  'deliveryFee': instance.deliveryFee,
  'serviceFee': instance.serviceFee,
  'isPriority': instance.isPriority,
  'priorityFee': instance.priorityFee,
  'notes': instance.notes,
  'estimatedReadyTime': instance.estimatedReadyTime?.toIso8601String(),
  'cancellationReason': instance.cancellationReason,
  'refundRequestReason': instance.refundRequestReason,
  'refundRequestedAt': instance.refundRequestedAt?.toIso8601String(),
  'refundedAmount': instance.refundedAmount,
  'refundId': instance.refundId,
};

const _$OrderStatusEnumMap = {
  OrderStatus.pending: 'Pending',
  OrderStatus.confirmed: 'Confirmed',
  OrderStatus.preparing: 'Preparing',
  OrderStatus.ready: 'Ready',
  OrderStatus.outForDelivery: 'Out for Delivery',
  OrderStatus.completed: 'Completed',
  OrderStatus.cancelled: 'Cancelled',
  OrderStatus.rejected: 'Rejected',
};

const _$PaymentStatusEnumMap = {
  PaymentStatus.pending: 'pending',
  PaymentStatus.processing: 'processing',
  PaymentStatus.paid: 'paid',
  PaymentStatus.failed: 'failed',
  PaymentStatus.refundRequested: 'refundRequested',
  PaymentStatus.refundPending: 'refundPending',
  PaymentStatus.refunded: 'refunded',
};

const _$FulfillmentMethodEnumMap = {
  FulfillmentMethod.delivery: 'Delivery',
  FulfillmentMethod.pickup: 'Pick-up',
};
