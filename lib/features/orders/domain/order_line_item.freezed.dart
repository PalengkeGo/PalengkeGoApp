// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_line_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrderLineItem {

 String get productId; String get productName; double get quantity; double get unitPrice;/// 'kg' or 'pc'
 String get unit; String get image;
/// Create a copy of OrderLineItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderLineItemCopyWith<OrderLineItem> get copyWith => _$OrderLineItemCopyWithImpl<OrderLineItem>(this as OrderLineItem, _$identity);

  /// Serializes this OrderLineItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderLineItem&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.image, image) || other.image == image));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productId,productName,quantity,unitPrice,unit,image);

@override
String toString() {
  return 'OrderLineItem(productId: $productId, productName: $productName, quantity: $quantity, unitPrice: $unitPrice, unit: $unit, image: $image)';
}


}

/// @nodoc
abstract mixin class $OrderLineItemCopyWith<$Res>  {
  factory $OrderLineItemCopyWith(OrderLineItem value, $Res Function(OrderLineItem) _then) = _$OrderLineItemCopyWithImpl;
@useResult
$Res call({
 String productId, String productName, double quantity, double unitPrice, String unit, String image
});




}
/// @nodoc
class _$OrderLineItemCopyWithImpl<$Res>
    implements $OrderLineItemCopyWith<$Res> {
  _$OrderLineItemCopyWithImpl(this._self, this._then);

  final OrderLineItem _self;
  final $Res Function(OrderLineItem) _then;

/// Create a copy of OrderLineItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productId = null,Object? productName = null,Object? quantity = null,Object? unitPrice = null,Object? unit = null,Object? image = null,}) {
  return _then(_self.copyWith(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,productName: null == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as double,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,image: null == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderLineItem].
extension OrderLineItemPatterns on OrderLineItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderLineItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderLineItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderLineItem value)  $default,){
final _that = this;
switch (_that) {
case _OrderLineItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderLineItem value)?  $default,){
final _that = this;
switch (_that) {
case _OrderLineItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String productId,  String productName,  double quantity,  double unitPrice,  String unit,  String image)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderLineItem() when $default != null:
return $default(_that.productId,_that.productName,_that.quantity,_that.unitPrice,_that.unit,_that.image);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String productId,  String productName,  double quantity,  double unitPrice,  String unit,  String image)  $default,) {final _that = this;
switch (_that) {
case _OrderLineItem():
return $default(_that.productId,_that.productName,_that.quantity,_that.unitPrice,_that.unit,_that.image);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String productId,  String productName,  double quantity,  double unitPrice,  String unit,  String image)?  $default,) {final _that = this;
switch (_that) {
case _OrderLineItem() when $default != null:
return $default(_that.productId,_that.productName,_that.quantity,_that.unitPrice,_that.unit,_that.image);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderLineItem extends OrderLineItem {
  const _OrderLineItem({required this.productId, required this.productName, required this.quantity, required this.unitPrice, this.unit = 'kg', this.image = ''}): super._();
  factory _OrderLineItem.fromJson(Map<String, dynamic> json) => _$OrderLineItemFromJson(json);

@override final  String productId;
@override final  String productName;
@override final  double quantity;
@override final  double unitPrice;
/// 'kg' or 'pc'
@override@JsonKey() final  String unit;
@override@JsonKey() final  String image;

/// Create a copy of OrderLineItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderLineItemCopyWith<_OrderLineItem> get copyWith => __$OrderLineItemCopyWithImpl<_OrderLineItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderLineItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderLineItem&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.image, image) || other.image == image));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productId,productName,quantity,unitPrice,unit,image);

@override
String toString() {
  return 'OrderLineItem(productId: $productId, productName: $productName, quantity: $quantity, unitPrice: $unitPrice, unit: $unit, image: $image)';
}


}

/// @nodoc
abstract mixin class _$OrderLineItemCopyWith<$Res> implements $OrderLineItemCopyWith<$Res> {
  factory _$OrderLineItemCopyWith(_OrderLineItem value, $Res Function(_OrderLineItem) _then) = __$OrderLineItemCopyWithImpl;
@override @useResult
$Res call({
 String productId, String productName, double quantity, double unitPrice, String unit, String image
});




}
/// @nodoc
class __$OrderLineItemCopyWithImpl<$Res>
    implements _$OrderLineItemCopyWith<$Res> {
  __$OrderLineItemCopyWithImpl(this._self, this._then);

  final _OrderLineItem _self;
  final $Res Function(_OrderLineItem) _then;

/// Create a copy of OrderLineItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productId = null,Object? productName = null,Object? quantity = null,Object? unitPrice = null,Object? unit = null,Object? image = null,}) {
  return _then(_OrderLineItem(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,productName: null == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as double,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,image: null == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
