// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'market_order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MarketOrder {

 String get id; String? get customerUid; String? get stallId; String get vendorName; String get vendorImage; String get customerName; OrderStatus get status; PaymentStatus get paymentStatus; String get paymentMethod; FulfillmentMethod get fulfillmentMethod; DateTime get placedAt; List<OrderLineItem> get items; String? get deliveryAddress; double get deliveryFee; double get serviceFee; bool get isPriority; double get priorityFee; String? get notes; DateTime? get estimatedReadyTime;/// Populated when status is cancelled or rejected.
/// Set by the vendor or system explaining why the order was not fulfilled.
 String? get cancellationReason;/// Customer's reason when they requested a refund (`refundRequested`).
 String? get refundRequestReason;/// When the customer requested a refund (`refundRequested`).
 DateTime? get refundRequestedAt;/// Running total already refunded, in pesos. Populated for partial refunds
/// so the UI can show how much of the order was returned.
 double get refundedAmount;/// PayMongo refund id (latest, if any).
 String? get refundId;
/// Create a copy of MarketOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MarketOrderCopyWith<MarketOrder> get copyWith => _$MarketOrderCopyWithImpl<MarketOrder>(this as MarketOrder, _$identity);

  /// Serializes this MarketOrder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MarketOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.customerUid, customerUid) || other.customerUid == customerUid)&&(identical(other.stallId, stallId) || other.stallId == stallId)&&(identical(other.vendorName, vendorName) || other.vendorName == vendorName)&&(identical(other.vendorImage, vendorImage) || other.vendorImage == vendorImage)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.status, status) || other.status == status)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.fulfillmentMethod, fulfillmentMethod) || other.fulfillmentMethod == fulfillmentMethod)&&(identical(other.placedAt, placedAt) || other.placedAt == placedAt)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.deliveryAddress, deliveryAddress) || other.deliveryAddress == deliveryAddress)&&(identical(other.deliveryFee, deliveryFee) || other.deliveryFee == deliveryFee)&&(identical(other.serviceFee, serviceFee) || other.serviceFee == serviceFee)&&(identical(other.isPriority, isPriority) || other.isPriority == isPriority)&&(identical(other.priorityFee, priorityFee) || other.priorityFee == priorityFee)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.estimatedReadyTime, estimatedReadyTime) || other.estimatedReadyTime == estimatedReadyTime)&&(identical(other.cancellationReason, cancellationReason) || other.cancellationReason == cancellationReason)&&(identical(other.refundRequestReason, refundRequestReason) || other.refundRequestReason == refundRequestReason)&&(identical(other.refundRequestedAt, refundRequestedAt) || other.refundRequestedAt == refundRequestedAt)&&(identical(other.refundedAmount, refundedAmount) || other.refundedAmount == refundedAmount)&&(identical(other.refundId, refundId) || other.refundId == refundId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,customerUid,stallId,vendorName,vendorImage,customerName,status,paymentStatus,paymentMethod,fulfillmentMethod,placedAt,const DeepCollectionEquality().hash(items),deliveryAddress,deliveryFee,serviceFee,isPriority,priorityFee,notes,estimatedReadyTime,cancellationReason,refundRequestReason,refundRequestedAt,refundedAmount,refundId]);

@override
String toString() {
  return 'MarketOrder(id: $id, customerUid: $customerUid, stallId: $stallId, vendorName: $vendorName, vendorImage: $vendorImage, customerName: $customerName, status: $status, paymentStatus: $paymentStatus, paymentMethod: $paymentMethod, fulfillmentMethod: $fulfillmentMethod, placedAt: $placedAt, items: $items, deliveryAddress: $deliveryAddress, deliveryFee: $deliveryFee, serviceFee: $serviceFee, isPriority: $isPriority, priorityFee: $priorityFee, notes: $notes, estimatedReadyTime: $estimatedReadyTime, cancellationReason: $cancellationReason, refundRequestReason: $refundRequestReason, refundRequestedAt: $refundRequestedAt, refundedAmount: $refundedAmount, refundId: $refundId)';
}


}

/// @nodoc
abstract mixin class $MarketOrderCopyWith<$Res>  {
  factory $MarketOrderCopyWith(MarketOrder value, $Res Function(MarketOrder) _then) = _$MarketOrderCopyWithImpl;
@useResult
$Res call({
 String id, String? customerUid, String? stallId, String vendorName, String vendorImage, String customerName, OrderStatus status, PaymentStatus paymentStatus, String paymentMethod, FulfillmentMethod fulfillmentMethod, DateTime placedAt, List<OrderLineItem> items, String? deliveryAddress, double deliveryFee, double serviceFee, bool isPriority, double priorityFee, String? notes, DateTime? estimatedReadyTime, String? cancellationReason, String? refundRequestReason, DateTime? refundRequestedAt, double refundedAmount, String? refundId
});




}
/// @nodoc
class _$MarketOrderCopyWithImpl<$Res>
    implements $MarketOrderCopyWith<$Res> {
  _$MarketOrderCopyWithImpl(this._self, this._then);

  final MarketOrder _self;
  final $Res Function(MarketOrder) _then;

/// Create a copy of MarketOrder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? customerUid = freezed,Object? stallId = freezed,Object? vendorName = null,Object? vendorImage = null,Object? customerName = null,Object? status = null,Object? paymentStatus = null,Object? paymentMethod = null,Object? fulfillmentMethod = null,Object? placedAt = null,Object? items = null,Object? deliveryAddress = freezed,Object? deliveryFee = null,Object? serviceFee = null,Object? isPriority = null,Object? priorityFee = null,Object? notes = freezed,Object? estimatedReadyTime = freezed,Object? cancellationReason = freezed,Object? refundRequestReason = freezed,Object? refundRequestedAt = freezed,Object? refundedAmount = null,Object? refundId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customerUid: freezed == customerUid ? _self.customerUid : customerUid // ignore: cast_nullable_to_non_nullable
as String?,stallId: freezed == stallId ? _self.stallId : stallId // ignore: cast_nullable_to_non_nullable
as String?,vendorName: null == vendorName ? _self.vendorName : vendorName // ignore: cast_nullable_to_non_nullable
as String,vendorImage: null == vendorImage ? _self.vendorImage : vendorImage // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as PaymentStatus,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,fulfillmentMethod: null == fulfillmentMethod ? _self.fulfillmentMethod : fulfillmentMethod // ignore: cast_nullable_to_non_nullable
as FulfillmentMethod,placedAt: null == placedAt ? _self.placedAt : placedAt // ignore: cast_nullable_to_non_nullable
as DateTime,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<OrderLineItem>,deliveryAddress: freezed == deliveryAddress ? _self.deliveryAddress : deliveryAddress // ignore: cast_nullable_to_non_nullable
as String?,deliveryFee: null == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as double,serviceFee: null == serviceFee ? _self.serviceFee : serviceFee // ignore: cast_nullable_to_non_nullable
as double,isPriority: null == isPriority ? _self.isPriority : isPriority // ignore: cast_nullable_to_non_nullable
as bool,priorityFee: null == priorityFee ? _self.priorityFee : priorityFee // ignore: cast_nullable_to_non_nullable
as double,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,estimatedReadyTime: freezed == estimatedReadyTime ? _self.estimatedReadyTime : estimatedReadyTime // ignore: cast_nullable_to_non_nullable
as DateTime?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,refundRequestReason: freezed == refundRequestReason ? _self.refundRequestReason : refundRequestReason // ignore: cast_nullable_to_non_nullable
as String?,refundRequestedAt: freezed == refundRequestedAt ? _self.refundRequestedAt : refundRequestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,refundedAmount: null == refundedAmount ? _self.refundedAmount : refundedAmount // ignore: cast_nullable_to_non_nullable
as double,refundId: freezed == refundId ? _self.refundId : refundId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MarketOrder].
extension MarketOrderPatterns on MarketOrder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MarketOrder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MarketOrder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MarketOrder value)  $default,){
final _that = this;
switch (_that) {
case _MarketOrder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MarketOrder value)?  $default,){
final _that = this;
switch (_that) {
case _MarketOrder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? customerUid,  String? stallId,  String vendorName,  String vendorImage,  String customerName,  OrderStatus status,  PaymentStatus paymentStatus,  String paymentMethod,  FulfillmentMethod fulfillmentMethod,  DateTime placedAt,  List<OrderLineItem> items,  String? deliveryAddress,  double deliveryFee,  double serviceFee,  bool isPriority,  double priorityFee,  String? notes,  DateTime? estimatedReadyTime,  String? cancellationReason,  String? refundRequestReason,  DateTime? refundRequestedAt,  double refundedAmount,  String? refundId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MarketOrder() when $default != null:
return $default(_that.id,_that.customerUid,_that.stallId,_that.vendorName,_that.vendorImage,_that.customerName,_that.status,_that.paymentStatus,_that.paymentMethod,_that.fulfillmentMethod,_that.placedAt,_that.items,_that.deliveryAddress,_that.deliveryFee,_that.serviceFee,_that.isPriority,_that.priorityFee,_that.notes,_that.estimatedReadyTime,_that.cancellationReason,_that.refundRequestReason,_that.refundRequestedAt,_that.refundedAmount,_that.refundId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? customerUid,  String? stallId,  String vendorName,  String vendorImage,  String customerName,  OrderStatus status,  PaymentStatus paymentStatus,  String paymentMethod,  FulfillmentMethod fulfillmentMethod,  DateTime placedAt,  List<OrderLineItem> items,  String? deliveryAddress,  double deliveryFee,  double serviceFee,  bool isPriority,  double priorityFee,  String? notes,  DateTime? estimatedReadyTime,  String? cancellationReason,  String? refundRequestReason,  DateTime? refundRequestedAt,  double refundedAmount,  String? refundId)  $default,) {final _that = this;
switch (_that) {
case _MarketOrder():
return $default(_that.id,_that.customerUid,_that.stallId,_that.vendorName,_that.vendorImage,_that.customerName,_that.status,_that.paymentStatus,_that.paymentMethod,_that.fulfillmentMethod,_that.placedAt,_that.items,_that.deliveryAddress,_that.deliveryFee,_that.serviceFee,_that.isPriority,_that.priorityFee,_that.notes,_that.estimatedReadyTime,_that.cancellationReason,_that.refundRequestReason,_that.refundRequestedAt,_that.refundedAmount,_that.refundId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? customerUid,  String? stallId,  String vendorName,  String vendorImage,  String customerName,  OrderStatus status,  PaymentStatus paymentStatus,  String paymentMethod,  FulfillmentMethod fulfillmentMethod,  DateTime placedAt,  List<OrderLineItem> items,  String? deliveryAddress,  double deliveryFee,  double serviceFee,  bool isPriority,  double priorityFee,  String? notes,  DateTime? estimatedReadyTime,  String? cancellationReason,  String? refundRequestReason,  DateTime? refundRequestedAt,  double refundedAmount,  String? refundId)?  $default,) {final _that = this;
switch (_that) {
case _MarketOrder() when $default != null:
return $default(_that.id,_that.customerUid,_that.stallId,_that.vendorName,_that.vendorImage,_that.customerName,_that.status,_that.paymentStatus,_that.paymentMethod,_that.fulfillmentMethod,_that.placedAt,_that.items,_that.deliveryAddress,_that.deliveryFee,_that.serviceFee,_that.isPriority,_that.priorityFee,_that.notes,_that.estimatedReadyTime,_that.cancellationReason,_that.refundRequestReason,_that.refundRequestedAt,_that.refundedAmount,_that.refundId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MarketOrder extends MarketOrder {
  const _MarketOrder({required this.id, this.customerUid, this.stallId, required this.vendorName, required this.vendorImage, this.customerName = 'Customer', required this.status, required this.paymentStatus, this.paymentMethod = 'cod', required this.fulfillmentMethod, required this.placedAt, required final  List<OrderLineItem> items, this.deliveryAddress, required this.deliveryFee, required this.serviceFee, this.isPriority = false, this.priorityFee = 0.0, this.notes, this.estimatedReadyTime, this.cancellationReason, this.refundRequestReason, this.refundRequestedAt, this.refundedAmount = 0.0, this.refundId}): _items = items,super._();
  factory _MarketOrder.fromJson(Map<String, dynamic> json) => _$MarketOrderFromJson(json);

@override final  String id;
@override final  String? customerUid;
@override final  String? stallId;
@override final  String vendorName;
@override final  String vendorImage;
@override@JsonKey() final  String customerName;
@override final  OrderStatus status;
@override final  PaymentStatus paymentStatus;
@override@JsonKey() final  String paymentMethod;
@override final  FulfillmentMethod fulfillmentMethod;
@override final  DateTime placedAt;
 final  List<OrderLineItem> _items;
@override List<OrderLineItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  String? deliveryAddress;
@override final  double deliveryFee;
@override final  double serviceFee;
@override@JsonKey() final  bool isPriority;
@override@JsonKey() final  double priorityFee;
@override final  String? notes;
@override final  DateTime? estimatedReadyTime;
/// Populated when status is cancelled or rejected.
/// Set by the vendor or system explaining why the order was not fulfilled.
@override final  String? cancellationReason;
/// Customer's reason when they requested a refund (`refundRequested`).
@override final  String? refundRequestReason;
/// When the customer requested a refund (`refundRequested`).
@override final  DateTime? refundRequestedAt;
/// Running total already refunded, in pesos. Populated for partial refunds
/// so the UI can show how much of the order was returned.
@override@JsonKey() final  double refundedAmount;
/// PayMongo refund id (latest, if any).
@override final  String? refundId;

/// Create a copy of MarketOrder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MarketOrderCopyWith<_MarketOrder> get copyWith => __$MarketOrderCopyWithImpl<_MarketOrder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MarketOrderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MarketOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.customerUid, customerUid) || other.customerUid == customerUid)&&(identical(other.stallId, stallId) || other.stallId == stallId)&&(identical(other.vendorName, vendorName) || other.vendorName == vendorName)&&(identical(other.vendorImage, vendorImage) || other.vendorImage == vendorImage)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.status, status) || other.status == status)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.fulfillmentMethod, fulfillmentMethod) || other.fulfillmentMethod == fulfillmentMethod)&&(identical(other.placedAt, placedAt) || other.placedAt == placedAt)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.deliveryAddress, deliveryAddress) || other.deliveryAddress == deliveryAddress)&&(identical(other.deliveryFee, deliveryFee) || other.deliveryFee == deliveryFee)&&(identical(other.serviceFee, serviceFee) || other.serviceFee == serviceFee)&&(identical(other.isPriority, isPriority) || other.isPriority == isPriority)&&(identical(other.priorityFee, priorityFee) || other.priorityFee == priorityFee)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.estimatedReadyTime, estimatedReadyTime) || other.estimatedReadyTime == estimatedReadyTime)&&(identical(other.cancellationReason, cancellationReason) || other.cancellationReason == cancellationReason)&&(identical(other.refundRequestReason, refundRequestReason) || other.refundRequestReason == refundRequestReason)&&(identical(other.refundRequestedAt, refundRequestedAt) || other.refundRequestedAt == refundRequestedAt)&&(identical(other.refundedAmount, refundedAmount) || other.refundedAmount == refundedAmount)&&(identical(other.refundId, refundId) || other.refundId == refundId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,customerUid,stallId,vendorName,vendorImage,customerName,status,paymentStatus,paymentMethod,fulfillmentMethod,placedAt,const DeepCollectionEquality().hash(_items),deliveryAddress,deliveryFee,serviceFee,isPriority,priorityFee,notes,estimatedReadyTime,cancellationReason,refundRequestReason,refundRequestedAt,refundedAmount,refundId]);

@override
String toString() {
  return 'MarketOrder(id: $id, customerUid: $customerUid, stallId: $stallId, vendorName: $vendorName, vendorImage: $vendorImage, customerName: $customerName, status: $status, paymentStatus: $paymentStatus, paymentMethod: $paymentMethod, fulfillmentMethod: $fulfillmentMethod, placedAt: $placedAt, items: $items, deliveryAddress: $deliveryAddress, deliveryFee: $deliveryFee, serviceFee: $serviceFee, isPriority: $isPriority, priorityFee: $priorityFee, notes: $notes, estimatedReadyTime: $estimatedReadyTime, cancellationReason: $cancellationReason, refundRequestReason: $refundRequestReason, refundRequestedAt: $refundRequestedAt, refundedAmount: $refundedAmount, refundId: $refundId)';
}


}

/// @nodoc
abstract mixin class _$MarketOrderCopyWith<$Res> implements $MarketOrderCopyWith<$Res> {
  factory _$MarketOrderCopyWith(_MarketOrder value, $Res Function(_MarketOrder) _then) = __$MarketOrderCopyWithImpl;
@override @useResult
$Res call({
 String id, String? customerUid, String? stallId, String vendorName, String vendorImage, String customerName, OrderStatus status, PaymentStatus paymentStatus, String paymentMethod, FulfillmentMethod fulfillmentMethod, DateTime placedAt, List<OrderLineItem> items, String? deliveryAddress, double deliveryFee, double serviceFee, bool isPriority, double priorityFee, String? notes, DateTime? estimatedReadyTime, String? cancellationReason, String? refundRequestReason, DateTime? refundRequestedAt, double refundedAmount, String? refundId
});




}
/// @nodoc
class __$MarketOrderCopyWithImpl<$Res>
    implements _$MarketOrderCopyWith<$Res> {
  __$MarketOrderCopyWithImpl(this._self, this._then);

  final _MarketOrder _self;
  final $Res Function(_MarketOrder) _then;

/// Create a copy of MarketOrder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? customerUid = freezed,Object? stallId = freezed,Object? vendorName = null,Object? vendorImage = null,Object? customerName = null,Object? status = null,Object? paymentStatus = null,Object? paymentMethod = null,Object? fulfillmentMethod = null,Object? placedAt = null,Object? items = null,Object? deliveryAddress = freezed,Object? deliveryFee = null,Object? serviceFee = null,Object? isPriority = null,Object? priorityFee = null,Object? notes = freezed,Object? estimatedReadyTime = freezed,Object? cancellationReason = freezed,Object? refundRequestReason = freezed,Object? refundRequestedAt = freezed,Object? refundedAmount = null,Object? refundId = freezed,}) {
  return _then(_MarketOrder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customerUid: freezed == customerUid ? _self.customerUid : customerUid // ignore: cast_nullable_to_non_nullable
as String?,stallId: freezed == stallId ? _self.stallId : stallId // ignore: cast_nullable_to_non_nullable
as String?,vendorName: null == vendorName ? _self.vendorName : vendorName // ignore: cast_nullable_to_non_nullable
as String,vendorImage: null == vendorImage ? _self.vendorImage : vendorImage // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as PaymentStatus,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,fulfillmentMethod: null == fulfillmentMethod ? _self.fulfillmentMethod : fulfillmentMethod // ignore: cast_nullable_to_non_nullable
as FulfillmentMethod,placedAt: null == placedAt ? _self.placedAt : placedAt // ignore: cast_nullable_to_non_nullable
as DateTime,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<OrderLineItem>,deliveryAddress: freezed == deliveryAddress ? _self.deliveryAddress : deliveryAddress // ignore: cast_nullable_to_non_nullable
as String?,deliveryFee: null == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as double,serviceFee: null == serviceFee ? _self.serviceFee : serviceFee // ignore: cast_nullable_to_non_nullable
as double,isPriority: null == isPriority ? _self.isPriority : isPriority // ignore: cast_nullable_to_non_nullable
as bool,priorityFee: null == priorityFee ? _self.priorityFee : priorityFee // ignore: cast_nullable_to_non_nullable
as double,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,estimatedReadyTime: freezed == estimatedReadyTime ? _self.estimatedReadyTime : estimatedReadyTime // ignore: cast_nullable_to_non_nullable
as DateTime?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,refundRequestReason: freezed == refundRequestReason ? _self.refundRequestReason : refundRequestReason // ignore: cast_nullable_to_non_nullable
as String?,refundRequestedAt: freezed == refundRequestedAt ? _self.refundRequestedAt : refundRequestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,refundedAmount: null == refundedAmount ? _self.refundedAmount : refundedAmount // ignore: cast_nullable_to_non_nullable
as double,refundId: freezed == refundId ? _self.refundId : refundId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
