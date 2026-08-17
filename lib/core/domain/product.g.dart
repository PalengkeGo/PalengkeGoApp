// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VendorProduct _$VendorProductFromJson(Map<String, dynamic> json) =>
    _VendorProduct(
      id: json['id'] as String,
      vendorId: json['vendorId'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'kg',
      imageUrl: json['imageUrl'] as String,
      isActive: json['isActive'] as bool? ?? true,
      stockQuantity: (json['stockQuantity'] as num?)?.toDouble() ?? 0.0,
      initialStockQuantity:
          (json['initialStockQuantity'] as num?)?.toDouble() ?? 0.0,
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$VendorProductToJson(_VendorProduct instance) =>
    <String, dynamic>{
      'id': instance.id,
      'vendorId': instance.vendorId,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'price': instance.price,
      'unit': instance.unit,
      'imageUrl': instance.imageUrl,
      'isActive': instance.isActive,
      'stockQuantity': instance.stockQuantity,
      'initialStockQuantity': instance.initialStockQuantity,
      'discountPercentage': instance.discountPercentage,
    };
