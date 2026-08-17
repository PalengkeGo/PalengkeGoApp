import 'package:palengkego/features/profile/domain/delivery_address.dart';

/// Customer-specific profile details.
///
/// Matches the CUSTOMERS ERD entity.
/// The parent [AppUser] holds auth-level fields (uid, email, role).
/// This class holds customer-specific profile data.
class CustomerProfile {
  const CustomerProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.phoneNumber,
    this.avatarUrl,
    this.savedAddress,
    this.latitude,
    this.longitude,
    this.addresses = const [],
  });

  final String uid;
  final String displayName;
  final String email;
  final String? phoneNumber;
  final String? avatarUrl;

  /// Last-used or default address label (e.g. 'Home').
  final String? savedAddress;

  /// Last known customer latitude — used for distance calculation.
  final double? latitude;

  /// Last known customer longitude — used for distance calculation.
  final double? longitude;

  /// Full list of saved addresses.
  final List<DeliveryAddress> addresses;

  /// Returns the default address or first address if none marked default.
  DeliveryAddress? get defaultAddress {
    try {
      return addresses.firstWhere((a) => a.isDefault);
    } catch (_) {
      return addresses.isNotEmpty ? addresses.first : null;
    }
  }

  CustomerProfile copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    String? savedAddress,
    double? latitude,
    double? longitude,
    List<DeliveryAddress>? addresses,
  }) {
    return CustomerProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      savedAddress: savedAddress ?? this.savedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      addresses: addresses ?? this.addresses,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'savedAddress': savedAddress,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory CustomerProfile.fromFirestore(Map<String, dynamic> data) {
    return CustomerProfile(
      uid: data['uid'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      savedAddress: data['savedAddress'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }
}
