// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vendor_stall.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VendorStall _$VendorStallFromJson(Map<String, dynamic> json) => _VendorStall(
  stallId: json['stallId'] as String,
  ownerUid: json['ownerUid'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  category: json['category'] as String,
  location: json['location'] as String,
  stallNumber: json['stallNumber'] as String?,
  floorNumber: json['floorNumber'] as String?,
  section: json['section'] as String?,
  bannerImage: json['bannerImage'] as String?,
  avatarImage: json['avatarImage'] as String?,
  thumbnailImage: json['thumbnailImage'] as String?,
  isOpen: json['isOpen'] as bool? ?? false,
  schedule:
      (json['schedule'] as List<dynamic>?)
          ?.map((e) => DaySchedule.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  deliverySettings: json['deliverySettings'] == null
      ? null
      : DeliverySettings.fromJson(
          json['deliverySettings'] as Map<String, dynamic>,
        ),
  isKYCApproved: json['isKYCApproved'] as bool? ?? false,
  kycStatus:
      $enumDecodeNullable(_$KycStatusEnumMap, json['kycStatus']) ??
      KycStatus.pending,
  licenseStatus:
      $enumDecodeNullable(_$LicenseStatusEnumMap, json['licenseStatus']) ??
      LicenseStatus.active,
  licenseExpiryDate: json['licenseExpiryDate'] == null
      ? null
      : DateTime.parse(json['licenseExpiryDate'] as String),
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
  totalRatings: (json['totalRatings'] as num?)?.toInt() ?? 0,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$VendorStallToJson(_VendorStall instance) =>
    <String, dynamic>{
      'stallId': instance.stallId,
      'ownerUid': instance.ownerUid,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'location': instance.location,
      'stallNumber': instance.stallNumber,
      'floorNumber': instance.floorNumber,
      'section': instance.section,
      'bannerImage': instance.bannerImage,
      'avatarImage': instance.avatarImage,
      'thumbnailImage': instance.thumbnailImage,
      'isOpen': instance.isOpen,
      'schedule': instance.schedule,
      'deliverySettings': instance.deliverySettings,
      'isKYCApproved': instance.isKYCApproved,
      'kycStatus': _$KycStatusEnumMap[instance.kycStatus]!,
      'licenseStatus': _$LicenseStatusEnumMap[instance.licenseStatus]!,
      'licenseExpiryDate': instance.licenseExpiryDate?.toIso8601String(),
      'tags': instance.tags,
      'averageRating': instance.averageRating,
      'totalRatings': instance.totalRatings,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$KycStatusEnumMap = {
  KycStatus.pending: 'pending',
  KycStatus.approved: 'approved',
  KycStatus.rejected: 'rejected',
};

const _$LicenseStatusEnumMap = {
  LicenseStatus.active: 'active',
  LicenseStatus.expiringSoon: 'expiring_soon',
  LicenseStatus.expired: 'expired',
  LicenseStatus.suspended: 'suspended',
  LicenseStatus.pending: 'pending',
};
