// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VendorProduct {

 String get id; String get vendorId; String get name; String get description; String get category; double get price;/// 'kg' or 'pc'
 String get unit; String get imageUrl; bool get isActive; double get stockQuantity;/// Captures the stock at creation time for low-stock % calculation.
 double get initialStockQuantity; double? get discountPercentage;
/// Create a copy of VendorProduct
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VendorProductCopyWith<VendorProduct> get copyWith => _$VendorProductCopyWithImpl<VendorProduct>(this as VendorProduct, _$identity);

  /// Serializes this VendorProduct to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VendorProduct&&(identical(other.id, id) || other.id == id)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.price, price) || other.price == price)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.initialStockQuantity, initialStockQuantity) || other.initialStockQuantity == initialStockQuantity)&&(identical(other.discountPercentage, discountPercentage) || other.discountPercentage == discountPercentage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,vendorId,name,description,category,price,unit,imageUrl,isActive,stockQuantity,initialStockQuantity,discountPercentage);

@override
String toString() {
  return 'VendorProduct(id: $id, vendorId: $vendorId, name: $name, description: $description, category: $category, price: $price, unit: $unit, imageUrl: $imageUrl, isActive: $isActive, stockQuantity: $stockQuantity, initialStockQuantity: $initialStockQuantity, discountPercentage: $discountPercentage)';
}


}

/// @nodoc
abstract mixin class $VendorProductCopyWith<$Res>  {
  factory $VendorProductCopyWith(VendorProduct value, $Res Function(VendorProduct) _then) = _$VendorProductCopyWithImpl;
@useResult
$Res call({
 String id, String vendorId, String name, String description, String category, double price, String unit, String imageUrl, bool isActive, double stockQuantity, double initialStockQuantity, double? discountPercentage
});




}
/// @nodoc
class _$VendorProductCopyWithImpl<$Res>
    implements $VendorProductCopyWith<$Res> {
  _$VendorProductCopyWithImpl(this._self, this._then);

  final VendorProduct _self;
  final $Res Function(VendorProduct) _then;

/// Create a copy of VendorProduct
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? vendorId = null,Object? name = null,Object? description = null,Object? category = null,Object? price = null,Object? unit = null,Object? imageUrl = null,Object? isActive = null,Object? stockQuantity = null,Object? initialStockQuantity = null,Object? discountPercentage = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as double,initialStockQuantity: null == initialStockQuantity ? _self.initialStockQuantity : initialStockQuantity // ignore: cast_nullable_to_non_nullable
as double,discountPercentage: freezed == discountPercentage ? _self.discountPercentage : discountPercentage // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [VendorProduct].
extension VendorProductPatterns on VendorProduct {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VendorProduct value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VendorProduct() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VendorProduct value)  $default,){
final _that = this;
switch (_that) {
case _VendorProduct():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VendorProduct value)?  $default,){
final _that = this;
switch (_that) {
case _VendorProduct() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String vendorId,  String name,  String description,  String category,  double price,  String unit,  String imageUrl,  bool isActive,  double stockQuantity,  double initialStockQuantity,  double? discountPercentage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VendorProduct() when $default != null:
return $default(_that.id,_that.vendorId,_that.name,_that.description,_that.category,_that.price,_that.unit,_that.imageUrl,_that.isActive,_that.stockQuantity,_that.initialStockQuantity,_that.discountPercentage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String vendorId,  String name,  String description,  String category,  double price,  String unit,  String imageUrl,  bool isActive,  double stockQuantity,  double initialStockQuantity,  double? discountPercentage)  $default,) {final _that = this;
switch (_that) {
case _VendorProduct():
return $default(_that.id,_that.vendorId,_that.name,_that.description,_that.category,_that.price,_that.unit,_that.imageUrl,_that.isActive,_that.stockQuantity,_that.initialStockQuantity,_that.discountPercentage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String vendorId,  String name,  String description,  String category,  double price,  String unit,  String imageUrl,  bool isActive,  double stockQuantity,  double initialStockQuantity,  double? discountPercentage)?  $default,) {final _that = this;
switch (_that) {
case _VendorProduct() when $default != null:
return $default(_that.id,_that.vendorId,_that.name,_that.description,_that.category,_that.price,_that.unit,_that.imageUrl,_that.isActive,_that.stockQuantity,_that.initialStockQuantity,_that.discountPercentage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VendorProduct extends VendorProduct {
  const _VendorProduct({required this.id, required this.vendorId, required this.name, required this.description, required this.category, required this.price, this.unit = 'kg', required this.imageUrl, this.isActive = true, this.stockQuantity = 0.0, this.initialStockQuantity = 0.0, this.discountPercentage}): super._();
  factory _VendorProduct.fromJson(Map<String, dynamic> json) => _$VendorProductFromJson(json);

@override final  String id;
@override final  String vendorId;
@override final  String name;
@override final  String description;
@override final  String category;
@override final  double price;
/// 'kg' or 'pc'
@override@JsonKey() final  String unit;
@override final  String imageUrl;
@override@JsonKey() final  bool isActive;
@override@JsonKey() final  double stockQuantity;
/// Captures the stock at creation time for low-stock % calculation.
@override@JsonKey() final  double initialStockQuantity;
@override final  double? discountPercentage;

/// Create a copy of VendorProduct
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VendorProductCopyWith<_VendorProduct> get copyWith => __$VendorProductCopyWithImpl<_VendorProduct>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VendorProductToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VendorProduct&&(identical(other.id, id) || other.id == id)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.price, price) || other.price == price)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.initialStockQuantity, initialStockQuantity) || other.initialStockQuantity == initialStockQuantity)&&(identical(other.discountPercentage, discountPercentage) || other.discountPercentage == discountPercentage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,vendorId,name,description,category,price,unit,imageUrl,isActive,stockQuantity,initialStockQuantity,discountPercentage);

@override
String toString() {
  return 'VendorProduct(id: $id, vendorId: $vendorId, name: $name, description: $description, category: $category, price: $price, unit: $unit, imageUrl: $imageUrl, isActive: $isActive, stockQuantity: $stockQuantity, initialStockQuantity: $initialStockQuantity, discountPercentage: $discountPercentage)';
}


}

/// @nodoc
abstract mixin class _$VendorProductCopyWith<$Res> implements $VendorProductCopyWith<$Res> {
  factory _$VendorProductCopyWith(_VendorProduct value, $Res Function(_VendorProduct) _then) = __$VendorProductCopyWithImpl;
@override @useResult
$Res call({
 String id, String vendorId, String name, String description, String category, double price, String unit, String imageUrl, bool isActive, double stockQuantity, double initialStockQuantity, double? discountPercentage
});




}
/// @nodoc
class __$VendorProductCopyWithImpl<$Res>
    implements _$VendorProductCopyWith<$Res> {
  __$VendorProductCopyWithImpl(this._self, this._then);

  final _VendorProduct _self;
  final $Res Function(_VendorProduct) _then;

/// Create a copy of VendorProduct
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? vendorId = null,Object? name = null,Object? description = null,Object? category = null,Object? price = null,Object? unit = null,Object? imageUrl = null,Object? isActive = null,Object? stockQuantity = null,Object? initialStockQuantity = null,Object? discountPercentage = freezed,}) {
  return _then(_VendorProduct(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as double,initialStockQuantity: null == initialStockQuantity ? _self.initialStockQuantity : initialStockQuantity // ignore: cast_nullable_to_non_nullable
as double,discountPercentage: freezed == discountPercentage ? _self.discountPercentage : discountPercentage // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
