enum UserRole { customer, vendor, admin }

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.role = UserRole.customer,
    this.phoneNumber,
    this.profilePhoto,
    this.isVerified = false,
    this.isBlocked = false,
  });

  final String uid;
  final String email;
  final String? displayName;
  final UserRole role;
  final String? phoneNumber;
  final String? profilePhoto;
  final bool isVerified;
  final bool isBlocked;

  bool get isVendor => role == UserRole.vendor;
  bool get isCustomer => role == UserRole.customer;
  bool get isAdmin => role == UserRole.admin;

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    String? phoneNumber,
    String? profilePhoto,
    bool? isVerified,
    bool? isBlocked,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      isVerified: isVerified ?? this.isVerified,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }
}

/// Mock users for development use — pre-seeded so no password needed.
class MockUsers {
  static const customer = AppUser(
    uid: 'customer-001',
    email: 'customer@palengkego.ph',
    displayName: 'Maria Santos',
    role: UserRole.customer,
  );

  static const vendor = AppUser(
    uid: 'stall holder-001',
    email: 'stall holder@palengkego.ph',
    displayName: 'Diosa Fruit Stand',
    role: UserRole.vendor,
  );
}
