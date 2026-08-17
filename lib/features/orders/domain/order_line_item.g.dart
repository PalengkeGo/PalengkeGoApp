// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_line_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OrderLineItem _$OrderLineItemFromJson(Map<String, dynamic> json) =>
    _OrderLineItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'kg',
      image: json['image'] as String? ?? '',
    );

Map<String, dynamic> _$OrderLineItemToJson(_OrderLineItem instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'productName': instance.productName,
      'quantity': instance.quantity,
      'unitPrice': instance.unitPrice,
      'unit': instance.unit,
      'image': instance.image,
    };
