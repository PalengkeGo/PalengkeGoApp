/// A customer's saved delivery address.
///
/// Matches the CUSTOMER_ADDRESSES ERD entity.
///
/// **Backward-compat note:** `primaryAddress` is kept as an alias for
/// `fullAddress` and `notes` is kept as an alias for `landmarks` so existing
/// UI call sites don't need to be mass-refactored.
class DeliveryAddress {
  const DeliveryAddress({
    this.addressId,
    this.label = 'other',
    String? fullAddress,
    String? primaryAddress, // backward-compat alias
    this.streetAddress = '',
    String? landmarks,
    String? notes, // backward-compat alias
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.contactName = '',
    this.iconCodePoint,
  }) : fullAddress = fullAddress ?? primaryAddress ?? '',
       landmarks = landmarks ?? notes ?? '';

  /// Firestore document ID — null until persisted.
  final String? addressId;

  /// 'home', 'office', or 'other'.
  final String label;

  /// Full formatted address string.
  final String fullAddress;

  /// Optional street-level detail (barangay, street name, etc.).
  final String streetAddress;

  /// Landmarks near the address (e.g. "beside the sari-sari store").
  final String landmarks;

  final double? latitude;
  final double? longitude;

  /// Optional Material Icon codePoint for custom label icon.
  final int? iconCodePoint;

  /// Backward-compat getter — same as [fullAddress].
  String get primaryAddress => fullAddress;

  /// Backward-compat getter — same as [landmarks].
  String get notes => landmarks;

  /// Whether this is the customer's default delivery address.
  final bool isDefault;

  /// Contact person for this address (name + phone).
  final String contactName;

  String get displayLine {
    if (streetAddress.trim().isEmpty) return fullAddress;
    return '$streetAddress, $fullAddress';
  }

  DeliveryAddress copyWith({
    String? addressId,
    String? label,
    String? fullAddress,
    String? streetAddress,
    String? landmarks,
    double? latitude,
    double? longitude,
    bool? isDefault,
    String? contactName,
    int? iconCodePoint,
  }) {
    return DeliveryAddress(
      addressId: addressId ?? this.addressId,
      label: label ?? this.label,
      fullAddress: fullAddress ?? this.fullAddress,
      streetAddress: streetAddress ?? this.streetAddress,
      landmarks: landmarks ?? this.landmarks,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      contactName: contactName ?? this.contactName,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'label': label,
      'fullAddress': fullAddress,
      'streetAddress': streetAddress,
      'landmarks': landmarks,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
      'contactName': contactName,
      'iconCodePoint': iconCodePoint,
    };
  }

  factory DeliveryAddress.fromFirestore(
    Map<String, dynamic> data, {
    String? id,
  }) {
    return DeliveryAddress(
      addressId: id,
      label: data['label'] as String? ?? 'other',
      fullAddress: data['fullAddress'] as String? ?? '',
      streetAddress: data['streetAddress'] as String? ?? '',
      landmarks: data['landmarks'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      isDefault: data['isDefault'] as bool? ?? false,
      contactName: data['contactName'] as String? ?? '',
      iconCodePoint: data['iconCodePoint'] as int?,
    );
  }
}
