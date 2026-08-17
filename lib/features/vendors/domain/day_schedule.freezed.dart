// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'day_schedule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DaySchedule {

 String get name; bool get isOpen;/// Store as string "HH:mm" for easy JSON serialization in Firestore
 String get openTime; String get closeTime;
/// Create a copy of DaySchedule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DayScheduleCopyWith<DaySchedule> get copyWith => _$DayScheduleCopyWithImpl<DaySchedule>(this as DaySchedule, _$identity);

  /// Serializes this DaySchedule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaySchedule&&(identical(other.name, name) || other.name == name)&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.openTime, openTime) || other.openTime == openTime)&&(identical(other.closeTime, closeTime) || other.closeTime == closeTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,isOpen,openTime,closeTime);

@override
String toString() {
  return 'DaySchedule(name: $name, isOpen: $isOpen, openTime: $openTime, closeTime: $closeTime)';
}


}

/// @nodoc
abstract mixin class $DayScheduleCopyWith<$Res>  {
  factory $DayScheduleCopyWith(DaySchedule value, $Res Function(DaySchedule) _then) = _$DayScheduleCopyWithImpl;
@useResult
$Res call({
 String name, bool isOpen, String openTime, String closeTime
});




}
/// @nodoc
class _$DayScheduleCopyWithImpl<$Res>
    implements $DayScheduleCopyWith<$Res> {
  _$DayScheduleCopyWithImpl(this._self, this._then);

  final DaySchedule _self;
  final $Res Function(DaySchedule) _then;

/// Create a copy of DaySchedule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? isOpen = null,Object? openTime = null,Object? closeTime = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,openTime: null == openTime ? _self.openTime : openTime // ignore: cast_nullable_to_non_nullable
as String,closeTime: null == closeTime ? _self.closeTime : closeTime // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DaySchedule].
extension DaySchedulePatterns on DaySchedule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DaySchedule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DaySchedule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DaySchedule value)  $default,){
final _that = this;
switch (_that) {
case _DaySchedule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DaySchedule value)?  $default,){
final _that = this;
switch (_that) {
case _DaySchedule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  bool isOpen,  String openTime,  String closeTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DaySchedule() when $default != null:
return $default(_that.name,_that.isOpen,_that.openTime,_that.closeTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  bool isOpen,  String openTime,  String closeTime)  $default,) {final _that = this;
switch (_that) {
case _DaySchedule():
return $default(_that.name,_that.isOpen,_that.openTime,_that.closeTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  bool isOpen,  String openTime,  String closeTime)?  $default,) {final _that = this;
switch (_that) {
case _DaySchedule() when $default != null:
return $default(_that.name,_that.isOpen,_that.openTime,_that.closeTime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DaySchedule implements DaySchedule {
  const _DaySchedule({required this.name, this.isOpen = true, this.openTime = "06:00", this.closeTime = "18:00"});
  factory _DaySchedule.fromJson(Map<String, dynamic> json) => _$DayScheduleFromJson(json);

@override final  String name;
@override@JsonKey() final  bool isOpen;
/// Store as string "HH:mm" for easy JSON serialization in Firestore
@override@JsonKey() final  String openTime;
@override@JsonKey() final  String closeTime;

/// Create a copy of DaySchedule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DayScheduleCopyWith<_DaySchedule> get copyWith => __$DayScheduleCopyWithImpl<_DaySchedule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DayScheduleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DaySchedule&&(identical(other.name, name) || other.name == name)&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.openTime, openTime) || other.openTime == openTime)&&(identical(other.closeTime, closeTime) || other.closeTime == closeTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,isOpen,openTime,closeTime);

@override
String toString() {
  return 'DaySchedule(name: $name, isOpen: $isOpen, openTime: $openTime, closeTime: $closeTime)';
}


}

/// @nodoc
abstract mixin class _$DayScheduleCopyWith<$Res> implements $DayScheduleCopyWith<$Res> {
  factory _$DayScheduleCopyWith(_DaySchedule value, $Res Function(_DaySchedule) _then) = __$DayScheduleCopyWithImpl;
@override @useResult
$Res call({
 String name, bool isOpen, String openTime, String closeTime
});




}
/// @nodoc
class __$DayScheduleCopyWithImpl<$Res>
    implements _$DayScheduleCopyWith<$Res> {
  __$DayScheduleCopyWithImpl(this._self, this._then);

  final _DaySchedule _self;
  final $Res Function(_DaySchedule) _then;

/// Create a copy of DaySchedule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? isOpen = null,Object? openTime = null,Object? closeTime = null,}) {
  return _then(_DaySchedule(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,openTime: null == openTime ? _self.openTime : openTime // ignore: cast_nullable_to_non_nullable
as String,closeTime: null == closeTime ? _self.closeTime : closeTime // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
