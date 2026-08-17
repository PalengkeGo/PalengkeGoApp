// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vendor_stall.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VendorStall {

/// Firestore document ID — matches the owning user's uid.
 String get stallId;/// UID of the vendor user who owns this stall.
 String get ownerUid; String get name; String get description;/// Category from the fixed list (e.g. 'Fresh Fish', 'Vegetables', etc.).
 String get category;/// Human-readable market location string (e.g. 'Section A, Stall 12').
 String get location;/// Physical stall number assigned by the market authority.
 String? get stallNumber;/// Floor of the market building.
 String? get floorNumber;/// Market section (e.g. 'A', 'B', 'Fish Section').
 String? get section; String? get bannerImage; String? get avatarImage; String? get thumbnailImage; bool get isOpen; List<DaySchedule> get schedule; DeliverySettings? get deliverySettings;/// Whether the KYC submission has been approved by an admin.
 bool get isKYCApproved;/// Current KYC verification state.
 KycStatus get kycStatus;/// Current license renewal status.
 LicenseStatus get licenseStatus;/// The date when the current license expires.
 DateTime? get licenseExpiryDate;/// Subcategory filtering tags (e.g., 'Beef', 'Pork').
 List<String>? get tags;/// Average customer rating (1–5). Updated by Cloud Function.
 double get averageRating;/// Total number of ratings received.
 int get totalRatings;/// Firestore server timestamp of when the stall was created.
 DateTime? get createdAt;
/// Create a copy of VendorStall
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VendorStallCopyWith<VendorStall> get copyWith => _$VendorStallCopyWithImpl<VendorStall>(this as VendorStall, _$identity);

  /// Serializes this VendorStall to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VendorStall&&(identical(other.stallId, stallId) || other.stallId == stallId)&&(identical(other.ownerUid, ownerUid) || other.ownerUid == ownerUid)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.location, location) || other.location == location)&&(identical(other.stallNumber, stallNumber) || other.stallNumber == stallNumber)&&(identical(other.floorNumber, floorNumber) || other.floorNumber == floorNumber)&&(identical(other.section, section) || other.section == section)&&(identical(other.bannerImage, bannerImage) || other.bannerImage == bannerImage)&&(identical(other.avatarImage, avatarImage) || other.avatarImage == avatarImage)&&(identical(other.thumbnailImage, thumbnailImage) || other.thumbnailImage == thumbnailImage)&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&const DeepCollectionEquality().equals(other.schedule, schedule)&&(identical(other.deliverySettings, deliverySettings) || other.deliverySettings == deliverySettings)&&(identical(other.isKYCApproved, isKYCApproved) || other.isKYCApproved == isKYCApproved)&&(identical(other.kycStatus, kycStatus) || other.kycStatus == kycStatus)&&(identical(other.licenseStatus, licenseStatus) || other.licenseStatus == licenseStatus)&&(identical(other.licenseExpiryDate, licenseExpiryDate) || other.licenseExpiryDate == licenseExpiryDate)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.averageRating, averageRating) || other.averageRating == averageRating)&&(identical(other.totalRatings, totalRatings) || other.totalRatings == totalRatings)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,stallId,ownerUid,name,description,category,location,stallNumber,floorNumber,section,bannerImage,avatarImage,thumbnailImage,isOpen,const DeepCollectionEquality().hash(schedule),deliverySettings,isKYCApproved,kycStatus,licenseStatus,licenseExpiryDate,const DeepCollectionEquality().hash(tags),averageRating,totalRatings,createdAt]);

@override
String toString() {
  return 'VendorStall(stallId: $stallId, ownerUid: $ownerUid, name: $name, description: $description, category: $category, location: $location, stallNumber: $stallNumber, floorNumber: $floorNumber, section: $section, bannerImage: $bannerImage, avatarImage: $avatarImage, thumbnailImage: $thumbnailImage, isOpen: $isOpen, schedule: $schedule, deliverySettings: $deliverySettings, isKYCApproved: $isKYCApproved, kycStatus: $kycStatus, licenseStatus: $licenseStatus, licenseExpiryDate: $licenseExpiryDate, tags: $tags, averageRating: $averageRating, totalRatings: $totalRatings, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $VendorStallCopyWith<$Res>  {
  factory $VendorStallCopyWith(VendorStall value, $Res Function(VendorStall) _then) = _$VendorStallCopyWithImpl;
@useResult
$Res call({
 String stallId, String ownerUid, String name, String description, String category, String location, String? stallNumber, String? floorNumber, String? section, String? bannerImage, String? avatarImage, String? thumbnailImage, bool isOpen, List<DaySchedule> schedule, DeliverySettings? deliverySettings, bool isKYCApproved, KycStatus kycStatus, LicenseStatus licenseStatus, DateTime? licenseExpiryDate, List<String>? tags, double averageRating, int totalRatings, DateTime? createdAt
});


$DeliverySettingsCopyWith<$Res>? get deliverySettings;

}
/// @nodoc
class _$VendorStallCopyWithImpl<$Res>
    implements $VendorStallCopyWith<$Res> {
  _$VendorStallCopyWithImpl(this._self, this._then);

  final VendorStall _self;
  final $Res Function(VendorStall) _then;

/// Create a copy of VendorStall
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stallId = null,Object? ownerUid = null,Object? name = null,Object? description = null,Object? category = null,Object? location = null,Object? stallNumber = freezed,Object? floorNumber = freezed,Object? section = freezed,Object? bannerImage = freezed,Object? avatarImage = freezed,Object? thumbnailImage = freezed,Object? isOpen = null,Object? schedule = null,Object? deliverySettings = freezed,Object? isKYCApproved = null,Object? kycStatus = null,Object? licenseStatus = null,Object? licenseExpiryDate = freezed,Object? tags = freezed,Object? averageRating = null,Object? totalRatings = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
stallId: null == stallId ? _self.stallId : stallId // ignore: cast_nullable_to_non_nullable
as String,ownerUid: null == ownerUid ? _self.ownerUid : ownerUid // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,stallNumber: freezed == stallNumber ? _self.stallNumber : stallNumber // ignore: cast_nullable_to_non_nullable
as String?,floorNumber: freezed == floorNumber ? _self.floorNumber : floorNumber // ignore: cast_nullable_to_non_nullable
as String?,section: freezed == section ? _self.section : section // ignore: cast_nullable_to_non_nullable
as String?,bannerImage: freezed == bannerImage ? _self.bannerImage : bannerImage // ignore: cast_nullable_to_non_nullable
as String?,avatarImage: freezed == avatarImage ? _self.avatarImage : avatarImage // ignore: cast_nullable_to_non_nullable
as String?,thumbnailImage: freezed == thumbnailImage ? _self.thumbnailImage : thumbnailImage // ignore: cast_nullable_to_non_nullable
as String?,isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,schedule: null == schedule ? _self.schedule : schedule // ignore: cast_nullable_to_non_nullable
as List<DaySchedule>,deliverySettings: freezed == deliverySettings ? _self.deliverySettings : deliverySettings // ignore: cast_nullable_to_non_nullable
as DeliverySettings?,isKYCApproved: null == isKYCApproved ? _self.isKYCApproved : isKYCApproved // ignore: cast_nullable_to_non_nullable
as bool,kycStatus: null == kycStatus ? _self.kycStatus : kycStatus // ignore: cast_nullable_to_non_nullable
as KycStatus,licenseStatus: null == licenseStatus ? _self.licenseStatus : licenseStatus // ignore: cast_nullable_to_non_nullable
as LicenseStatus,licenseExpiryDate: freezed == licenseExpiryDate ? _self.licenseExpiryDate : licenseExpiryDate // ignore: cast_nullable_to_non_nullable
as DateTime?,tags: freezed == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,averageRating: null == averageRating ? _self.averageRating : averageRating // ignore: cast_nullable_to_non_nullable
as double,totalRatings: null == totalRatings ? _self.totalRatings : totalRatings // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of VendorStall
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeliverySettingsCopyWith<$Res>? get deliverySettings {
    if (_self.deliverySettings == null) {
    return null;
  }

  return $DeliverySettingsCopyWith<$Res>(_self.deliverySettings!, (value) {
    return _then(_self.copyWith(deliverySettings: value));
  });
}
}


/// Adds pattern-matching-related methods to [VendorStall].
extension VendorStallPatterns on VendorStall {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VendorStall value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VendorStall() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VendorStall value)  $default,){
final _that = this;
switch (_that) {
case _VendorStall():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VendorStall value)?  $default,){
final _that = this;
switch (_that) {
case _VendorStall() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String stallId,  String ownerUid,  String name,  String description,  String category,  String location,  String? stallNumber,  String? floorNumber,  String? section,  String? bannerImage,  String? avatarImage,  String? thumbnailImage,  bool isOpen,  List<DaySchedule> schedule,  DeliverySettings? deliverySettings,  bool isKYCApproved,  KycStatus kycStatus,  LicenseStatus licenseStatus,  DateTime? licenseExpiryDate,  List<String>? tags,  double averageRating,  int totalRatings,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VendorStall() when $default != null:
return $default(_that.stallId,_that.ownerUid,_that.name,_that.description,_that.category,_that.location,_that.stallNumber,_that.floorNumber,_that.section,_that.bannerImage,_that.avatarImage,_that.thumbnailImage,_that.isOpen,_that.schedule,_that.deliverySettings,_that.isKYCApproved,_that.kycStatus,_that.licenseStatus,_that.licenseExpiryDate,_that.tags,_that.averageRating,_that.totalRatings,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String stallId,  String ownerUid,  String name,  String description,  String category,  String location,  String? stallNumber,  String? floorNumber,  String? section,  String? bannerImage,  String? avatarImage,  String? thumbnailImage,  bool isOpen,  List<DaySchedule> schedule,  DeliverySettings? deliverySettings,  bool isKYCApproved,  KycStatus kycStatus,  LicenseStatus licenseStatus,  DateTime? licenseExpiryDate,  List<String>? tags,  double averageRating,  int totalRatings,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _VendorStall():
return $default(_that.stallId,_that.ownerUid,_that.name,_that.description,_that.category,_that.location,_that.stallNumber,_that.floorNumber,_that.section,_that.bannerImage,_that.avatarImage,_that.thumbnailImage,_that.isOpen,_that.schedule,_that.deliverySettings,_that.isKYCApproved,_that.kycStatus,_that.licenseStatus,_that.licenseExpiryDate,_that.tags,_that.averageRating,_that.totalRatings,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String stallId,  String ownerUid,  String name,  String description,  String category,  String location,  String? stallNumber,  String? floorNumber,  String? section,  String? bannerImage,  String? avatarImage,  String? thumbnailImage,  bool isOpen,  List<DaySchedule> schedule,  DeliverySettings? deliverySettings,  bool isKYCApproved,  KycStatus kycStatus,  LicenseStatus licenseStatus,  DateTime? licenseExpiryDate,  List<String>? tags,  double averageRating,  int totalRatings,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _VendorStall() when $default != null:
return $default(_that.stallId,_that.ownerUid,_that.name,_that.description,_that.category,_that.location,_that.stallNumber,_that.floorNumber,_that.section,_that.bannerImage,_that.avatarImage,_that.thumbnailImage,_that.isOpen,_that.schedule,_that.deliverySettings,_that.isKYCApproved,_that.kycStatus,_that.licenseStatus,_that.licenseExpiryDate,_that.tags,_that.averageRating,_that.totalRatings,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VendorStall extends VendorStall {
  const _VendorStall({required this.stallId, required this.ownerUid, required this.name, required this.description, required this.category, required this.location, this.stallNumber, this.floorNumber, this.section, this.bannerImage, this.avatarImage, this.thumbnailImage, this.isOpen = false, final  List<DaySchedule> schedule = const [], this.deliverySettings, this.isKYCApproved = false, this.kycStatus = KycStatus.pending, this.licenseStatus = LicenseStatus.active, this.licenseExpiryDate, final  List<String>? tags, this.averageRating = 0.0, this.totalRatings = 0, this.createdAt}): _schedule = schedule,_tags = tags,super._();
  factory _VendorStall.fromJson(Map<String, dynamic> json) => _$VendorStallFromJson(json);

/// Firestore document ID — matches the owning user's uid.
@override final  String stallId;
/// UID of the vendor user who owns this stall.
@override final  String ownerUid;
@override final  String name;
@override final  String description;
/// Category from the fixed list (e.g. 'Fresh Fish', 'Vegetables', etc.).
@override final  String category;
/// Human-readable market location string (e.g. 'Section A, Stall 12').
@override final  String location;
/// Physical stall number assigned by the market authority.
@override final  String? stallNumber;
/// Floor of the market building.
@override final  String? floorNumber;
/// Market section (e.g. 'A', 'B', 'Fish Section').
@override final  String? section;
@override final  String? bannerImage;
@override final  String? avatarImage;
@override final  String? thumbnailImage;
@override@JsonKey() final  bool isOpen;
 final  List<DaySchedule> _schedule;
@override@JsonKey() List<DaySchedule> get schedule {
  if (_schedule is EqualUnmodifiableListView) return _schedule;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_schedule);
}

@override final  DeliverySettings? deliverySettings;
/// Whether the KYC submission has been approved by an admin.
@override@JsonKey() final  bool isKYCApproved;
/// Current KYC verification state.
@override@JsonKey() final  KycStatus kycStatus;
/// Current license renewal status.
@override@JsonKey() final  LicenseStatus licenseStatus;
/// The date when the current license expires.
@override final  DateTime? licenseExpiryDate;
/// Subcategory filtering tags (e.g., 'Beef', 'Pork').
 final  List<String>? _tags;
/// Subcategory filtering tags (e.g., 'Beef', 'Pork').
@override List<String>? get tags {
  final value = _tags;
  if (value == null) return null;
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// Average customer rating (1–5). Updated by Cloud Function.
@override@JsonKey() final  double averageRating;
/// Total number of ratings received.
@override@JsonKey() final  int totalRatings;
/// Firestore server timestamp of when the stall was created.
@override final  DateTime? createdAt;

/// Create a copy of VendorStall
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VendorStallCopyWith<_VendorStall> get copyWith => __$VendorStallCopyWithImpl<_VendorStall>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VendorStallToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VendorStall&&(identical(other.stallId, stallId) || other.stallId == stallId)&&(identical(other.ownerUid, ownerUid) || other.ownerUid == ownerUid)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.location, location) || other.location == location)&&(identical(other.stallNumber, stallNumber) || other.stallNumber == stallNumber)&&(identical(other.floorNumber, floorNumber) || other.floorNumber == floorNumber)&&(identical(other.section, section) || other.section == section)&&(identical(other.bannerImage, bannerImage) || other.bannerImage == bannerImage)&&(identical(other.avatarImage, avatarImage) || other.avatarImage == avatarImage)&&(identical(other.thumbnailImage, thumbnailImage) || other.thumbnailImage == thumbnailImage)&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&const DeepCollectionEquality().equals(other._schedule, _schedule)&&(identical(other.deliverySettings, deliverySettings) || other.deliverySettings == deliverySettings)&&(identical(other.isKYCApproved, isKYCApproved) || other.isKYCApproved == isKYCApproved)&&(identical(other.kycStatus, kycStatus) || other.kycStatus == kycStatus)&&(identical(other.licenseStatus, licenseStatus) || other.licenseStatus == licenseStatus)&&(identical(other.licenseExpiryDate, licenseExpiryDate) || other.licenseExpiryDate == licenseExpiryDate)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.averageRating, averageRating) || other.averageRating == averageRating)&&(identical(other.totalRatings, totalRatings) || other.totalRatings == totalRatings)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,stallId,ownerUid,name,description,category,location,stallNumber,floorNumber,section,bannerImage,avatarImage,thumbnailImage,isOpen,const DeepCollectionEquality().hash(_schedule),deliverySettings,isKYCApproved,kycStatus,licenseStatus,licenseExpiryDate,const DeepCollectionEquality().hash(_tags),averageRating,totalRatings,createdAt]);

@override
String toString() {
  return 'VendorStall(stallId: $stallId, ownerUid: $ownerUid, name: $name, description: $description, category: $category, location: $location, stallNumber: $stallNumber, floorNumber: $floorNumber, section: $section, bannerImage: $bannerImage, avatarImage: $avatarImage, thumbnailImage: $thumbnailImage, isOpen: $isOpen, schedule: $schedule, deliverySettings: $deliverySettings, isKYCApproved: $isKYCApproved, kycStatus: $kycStatus, licenseStatus: $licenseStatus, licenseExpiryDate: $licenseExpiryDate, tags: $tags, averageRating: $averageRating, totalRatings: $totalRatings, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$VendorStallCopyWith<$Res> implements $VendorStallCopyWith<$Res> {
  factory _$VendorStallCopyWith(_VendorStall value, $Res Function(_VendorStall) _then) = __$VendorStallCopyWithImpl;
@override @useResult
$Res call({
 String stallId, String ownerUid, String name, String description, String category, String location, String? stallNumber, String? floorNumber, String? section, String? bannerImage, String? avatarImage, String? thumbnailImage, bool isOpen, List<DaySchedule> schedule, DeliverySettings? deliverySettings, bool isKYCApproved, KycStatus kycStatus, LicenseStatus licenseStatus, DateTime? licenseExpiryDate, List<String>? tags, double averageRating, int totalRatings, DateTime? createdAt
});


@override $DeliverySettingsCopyWith<$Res>? get deliverySettings;

}
/// @nodoc
class __$VendorStallCopyWithImpl<$Res>
    implements _$VendorStallCopyWith<$Res> {
  __$VendorStallCopyWithImpl(this._self, this._then);

  final _VendorStall _self;
  final $Res Function(_VendorStall) _then;

/// Create a copy of VendorStall
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stallId = null,Object? ownerUid = null,Object? name = null,Object? description = null,Object? category = null,Object? location = null,Object? stallNumber = freezed,Object? floorNumber = freezed,Object? section = freezed,Object? bannerImage = freezed,Object? avatarImage = freezed,Object? thumbnailImage = freezed,Object? isOpen = null,Object? schedule = null,Object? deliverySettings = freezed,Object? isKYCApproved = null,Object? kycStatus = null,Object? licenseStatus = null,Object? licenseExpiryDate = freezed,Object? tags = freezed,Object? averageRating = null,Object? totalRatings = null,Object? createdAt = freezed,}) {
  return _then(_VendorStall(
stallId: null == stallId ? _self.stallId : stallId // ignore: cast_nullable_to_non_nullable
as String,ownerUid: null == ownerUid ? _self.ownerUid : ownerUid // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,stallNumber: freezed == stallNumber ? _self.stallNumber : stallNumber // ignore: cast_nullable_to_non_nullable
as String?,floorNumber: freezed == floorNumber ? _self.floorNumber : floorNumber // ignore: cast_nullable_to_non_nullable
as String?,section: freezed == section ? _self.section : section // ignore: cast_nullable_to_non_nullable
as String?,bannerImage: freezed == bannerImage ? _self.bannerImage : bannerImage // ignore: cast_nullable_to_non_nullable
as String?,avatarImage: freezed == avatarImage ? _self.avatarImage : avatarImage // ignore: cast_nullable_to_non_nullable
as String?,thumbnailImage: freezed == thumbnailImage ? _self.thumbnailImage : thumbnailImage // ignore: cast_nullable_to_non_nullable
as String?,isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,schedule: null == schedule ? _self._schedule : schedule // ignore: cast_nullable_to_non_nullable
as List<DaySchedule>,deliverySettings: freezed == deliverySettings ? _self.deliverySettings : deliverySettings // ignore: cast_nullable_to_non_nullable
as DeliverySettings?,isKYCApproved: null == isKYCApproved ? _self.isKYCApproved : isKYCApproved // ignore: cast_nullable_to_non_nullable
as bool,kycStatus: null == kycStatus ? _self.kycStatus : kycStatus // ignore: cast_nullable_to_non_nullable
as KycStatus,licenseStatus: null == licenseStatus ? _self.licenseStatus : licenseStatus // ignore: cast_nullable_to_non_nullable
as LicenseStatus,licenseExpiryDate: freezed == licenseExpiryDate ? _self.licenseExpiryDate : licenseExpiryDate // ignore: cast_nullable_to_non_nullable
as DateTime?,tags: freezed == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,averageRating: null == averageRating ? _self.averageRating : averageRating // ignore: cast_nullable_to_non_nullable
as double,totalRatings: null == totalRatings ? _self.totalRatings : totalRatings // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of VendorStall
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeliverySettingsCopyWith<$Res>? get deliverySettings {
    if (_self.deliverySettings == null) {
    return null;
  }

  return $DeliverySettingsCopyWith<$Res>(_self.deliverySettings!, (value) {
    return _then(_self.copyWith(deliverySettings: value));
  });
}
}

// dart format on
