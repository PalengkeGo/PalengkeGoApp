import 'package:freezed_annotation/freezed_annotation.dart';
import 'day_schedule.dart';
import 'delivery_settings.dart';

part 'vendor_stall.freezed.dart';
part 'vendor_stall.g.dart';

/// KYC / account verification status for a vendor stall.
/// Maps to `kycStatus` in the STALL_HOLDERS ERD entity.
enum KycStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected,
}

/// License status for a vendor stall.
enum LicenseStatus {
  @JsonValue('active')
  active,
  @JsonValue('expiring_soon')
  expiringSoon,
  @JsonValue('expired')
  expired,
  @JsonValue('suspended')
  suspended,
  @JsonValue('pending')
  pending,
}

/// A vendor's market stall profile.
///
/// Matches the STALL_HOLDERS ERD entity.
@freezed
abstract class VendorStall with _$VendorStall {
  const VendorStall._();

  const factory VendorStall({
    /// Firestore document ID — matches the owning user's uid.
    required String stallId,

    /// UID of the vendor user who owns this stall.
    required String ownerUid,

    required String name,
    required String description,

    /// Category from the fixed list (e.g. 'Fresh Fish', 'Vegetables', etc.).
    required String category,

    /// Human-readable market location string (e.g. 'Section A, Stall 12').
    required String location,

    /// Physical stall number assigned by the market authority.
    String? stallNumber,

    /// Floor of the market building.
    String? floorNumber,

    /// Market section (e.g. 'A', 'B', 'Fish Section').
    String? section,

    String? bannerImage,
    String? avatarImage,
    String? thumbnailImage,
    @Default(false) bool isOpen,
    @Default([]) List<DaySchedule> schedule,
    DeliverySettings? deliverySettings,

    /// Whether the KYC submission has been approved by an admin.
    @Default(false) bool isKYCApproved,

    /// Current KYC verification state.
    @Default(KycStatus.pending) KycStatus kycStatus,

    /// Current license renewal status.
    @Default(LicenseStatus.active) LicenseStatus licenseStatus,

    /// The date when the current license expires.
    DateTime? licenseExpiryDate,

    /// Subcategory filtering tags (e.g., 'Beef', 'Pork').
    List<String>? tags,

    /// Average customer rating (1–5). Updated by Cloud Function.
    @Default(0.0) double averageRating,

    /// Total number of ratings received.
    @Default(0) int totalRatings,

    /// Firestore server timestamp of when the stall was created.
    DateTime? createdAt,
  }) = _VendorStall;

  factory VendorStall.fromJson(Map<String, dynamic> json) =>
      _$VendorStallFromJson(json);
}
