import 'package:palengkego/features/profile/data/profile_repository.dart';
import 'package:palengkego/features/profile/domain/customer_profile.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

class MockProfileRepository implements ProfileRepository {
  CustomerProfile _currentProfile = const CustomerProfile(
    uid: 'user-123',
    displayName: 'Juan Dela Cruz',
    email: 'juan@example.com',
    phoneNumber: '+63 912 345 6789',
    avatarUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=face',
    addresses: [
      DeliveryAddress(
        addressId: 'addr-1',
        label: 'home',
        fullAddress: '123 Magsaysay Ave, Naga City, Camarines Sur',
        isDefault: true,
      ),
      DeliveryAddress(
        addressId: 'addr-2',
        label: 'other',
        fullAddress: '456 Panganiban Drive, Naga City, Camarines Sur',
      ),
    ],
  );

  // In-memory address store (mirrors _currentProfile.addresses for mutation).
  final List<DeliveryAddress> _addresses = [
    const DeliveryAddress(
      addressId: 'addr-1',
      label: 'home',
      fullAddress: '123 Magsaysay Ave, Naga City, Camarines Sur',
      isDefault: true,
    ),
    const DeliveryAddress(
      addressId: 'addr-2',
      label: 'other',
      fullAddress: '456 Panganiban Drive, Naga City, Camarines Sur',
    ),
  ];

  int _addressIdCounter = 3;

  @override
  Future<CustomerProfile> getProfile(String uid) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _currentProfile;
  }

  @override
  Future<void> updateProfile(CustomerProfile profile) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _currentProfile = profile;
  }

  // ── Address CRUD ─────────────────────────────────────────────────────────────

  @override
  Future<List<DeliveryAddress>> getAddresses(String uid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_addresses);
  }

  @override
  Future<DeliveryAddress> addAddress(
    String uid,
    DeliveryAddress address,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final saved = address.copyWith(
      addressId: 'addr-${_addressIdCounter++}',
      isDefault: _addresses.isEmpty ? true : address.isDefault,
    );
    if (saved.isDefault) {
      // Clear default on all others.
      for (var i = 0; i < _addresses.length; i++) {
        if (_addresses[i].isDefault) {
          _addresses[i] = _addresses[i].copyWith(isDefault: false);
        }
      }
    }
    _addresses.add(saved);
    return saved;
  }

  @override
  Future<void> updateAddress(String uid, DeliveryAddress address) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _addresses.indexWhere((a) => a.addressId == address.addressId);
    if (idx != -1) {
      if (address.isDefault) {
        for (var i = 0; i < _addresses.length; i++) {
          _addresses[i] = _addresses[i].copyWith(isDefault: false);
        }
      }
      _addresses[idx] = address;
    }
  }

  @override
  Future<void> deleteAddress(String uid, String addressId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _addresses.removeWhere((a) => a.addressId == addressId);
    // If we deleted the default and there are others, promote the first one.
    if (_addresses.isNotEmpty && !_addresses.any((a) => a.isDefault)) {
      _addresses[0] = _addresses[0].copyWith(isDefault: true);
    }
  }

  @override
  Future<void> setDefaultAddress(String uid, String addressId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    for (var i = 0; i < _addresses.length; i++) {
      _addresses[i] = _addresses[i].copyWith(
        isDefault: _addresses[i].addressId == addressId,
      );
    }
  }
}
