// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CartItem _$CartItemFromJson(Map<String, dynamic> json) => _CartItem(
  productId: json['productId'] as String,
  vendorName: json['vendorName'] as String,
  productName: json['productName'] as String,
  price: (json['price'] as num).toDouble(),
  unit: json['unit'] as String? ?? 'kg',
  image: json['image'] as String,
  quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
  selected: json['selected'] as bool? ?? true,
  stockQuantity: (json['stockQuantity'] as num?)?.toDouble() ?? 10.0,
);

Map<String, dynamic> _$CartItemToJson(_CartItem instance) => <String, dynamic>{
  'productId': instance.productId,
  'vendorName': instance.vendorName,
  'productName': instance.productName,
  'price': instance.price,
  'unit': instance.unit,
  'image': instance.image,
  'quantity': instance.quantity,
  'selected': instance.selected,
  'stockQuantity': instance.stockQuantity,
};
