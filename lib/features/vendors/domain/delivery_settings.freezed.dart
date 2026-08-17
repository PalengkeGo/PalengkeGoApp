// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'delivery_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeliverySettings {

 bool get isAvailableToDeliver;/// e.g., 'lalamove', 'grabexpress', or 'none'
 String get preferredThirdPartyBooking;
/// Create a copy of DeliverySettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeliverySettingsCopyWith<DeliverySettings> get copyWith => _$DeliverySettingsCopyWithImpl<DeliverySettings>(this as DeliverySettings, _$identity);

  /// Serializes this DeliverySettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliverySettings&&(identical(other.isAvailableToDeliver, isAvailableToDeliver) || other.isAvailableToDeliver == isAvailableToDeliver)&&(identical(other.preferredThirdPartyBooking, preferredThirdPartyBooking) || other.preferredThirdPartyBooking == preferredThirdPartyBooking));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isAvailableToDeliver,preferredThirdPartyBooking);

@override
String toString() {
  return 'DeliverySettings(isAvailableToDeliver: $isAvailableToDeliver, preferredThirdPartyBooking: $preferredThirdPartyBooking)';
}


}

/// @nodoc
abstract mixin class $DeliverySettingsCopyWith<$Res>  {
  factory $DeliverySettingsCopyWith(DeliverySettings value, $Res Function(DeliverySettings) _then) = _$DeliverySettingsCopyWithImpl;
@useResult
$Res call({
 bool isAvailableToDeliver, String preferredThirdPartyBooking
});




}
/// @nodoc
class _$DeliverySettingsCopyWithImpl<$Res>
    implements $DeliverySettingsCopyWith<$Res> {
  _$DeliverySettingsCopyWithImpl(this._self, this._then);

  final DeliverySettings _self;
  final $Res Function(DeliverySettings) _then;

/// Create a copy of DeliverySettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isAvailableToDeliver = null,Object? preferredThirdPartyBooking = null,}) {
  return _then(_self.copyWith(
isAvailableToDeliver: null == isAvailableToDeliver ? _self.isAvailableToDeliver : isAvailableToDeliver // ignore: cast_nullable_to_non_nullable
as bool,preferredThirdPartyBooking: null == preferredThirdPartyBooking ? _self.preferredThirdPartyBooking : preferredThirdPartyBooking // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DeliverySettings].
extension DeliverySettingsPatterns on DeliverySettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeliverySettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeliverySettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeliverySettings value)  $default,){
final _that = this;
switch (_that) {
case _DeliverySettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeliverySettings value)?  $default,){
final _that = this;
switch (_that) {
case _DeliverySettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isAvailableToDeliver,  String preferredThirdPartyBooking)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeliverySettings() when $default != null:
return $default(_that.isAvailableToDeliver,_that.preferredThirdPartyBooking);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isAvailableToDeliver,  String preferredThirdPartyBooking)  $default,) {final _that = this;
switch (_that) {
case _DeliverySettings():
return $default(_that.isAvailableToDeliver,_that.preferredThirdPartyBooking);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isAvailableToDeliver,  String preferredThirdPartyBooking)?  $default,) {final _that = this;
switch (_that) {
case _DeliverySettings() when $default != null:
return $default(_that.isAvailableToDeliver,_that.preferredThirdPartyBooking);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeliverySettings implements DeliverySettings {
  const _DeliverySettings({this.isAvailableToDeliver = false, this.preferredThirdPartyBooking = 'none'});
  factory _DeliverySettings.fromJson(Map<String, dynamic> json) => _$DeliverySettingsFromJson(json);

@override@JsonKey() final  bool isAvailableToDeliver;
/// e.g., 'lalamove', 'grabexpress', or 'none'
@override@JsonKey() final  String preferredThirdPartyBooking;

/// Create a copy of DeliverySettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeliverySettingsCopyWith<_DeliverySettings> get copyWith => __$DeliverySettingsCopyWithImpl<_DeliverySettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeliverySettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeliverySettings&&(identical(other.isAvailableToDeliver, isAvailableToDeliver) || other.isAvailableToDeliver == isAvailableToDeliver)&&(identical(other.preferredThirdPartyBooking, preferredThirdPartyBooking) || other.preferredThirdPartyBooking == preferredThirdPartyBooking));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isAvailableToDeliver,preferredThirdPartyBooking);

@override
String toString() {
  return 'DeliverySettings(isAvailableToDeliver: $isAvailableToDeliver, preferredThirdPartyBooking: $preferredThirdPartyBooking)';
}


}

/// @nodoc
abstract mixin class _$DeliverySettingsCopyWith<$Res> implements $DeliverySettingsCopyWith<$Res> {
  factory _$DeliverySettingsCopyWith(_DeliverySettings value, $Res Function(_DeliverySettings) _then) = __$DeliverySettingsCopyWithImpl;
@override @useResult
$Res call({
 bool isAvailableToDeliver, String preferredThirdPartyBooking
});




}
/// @nodoc
class __$DeliverySettingsCopyWithImpl<$Res>
    implements _$DeliverySettingsCopyWith<$Res> {
  __$DeliverySettingsCopyWithImpl(this._self, this._then);

  final _DeliverySettings _self;
  final $Res Function(_DeliverySettings) _then;

/// Create a copy of DeliverySettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isAvailableToDeliver = null,Object? preferredThirdPartyBooking = null,}) {
  return _then(_DeliverySettings(
isAvailableToDeliver: null == isAvailableToDeliver ? _self.isAvailableToDeliver : isAvailableToDeliver // ignore: cast_nullable_to_non_nullable
as bool,preferredThirdPartyBooking: null == preferredThirdPartyBooking ? _self.preferredThirdPartyBooking : preferredThirdPartyBooking // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
