import 'package:palengkego/features/profile/data/profile_repository.dart';
import 'package:palengkego/features/profile/domain/customer_profile.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

class MockProfileRepository implements ProfileRepository {
  CustomerProfile? _currentProfile;

  // In-memory address store.
  final List<DeliveryAddress> _addresses = [];

  int _addressIdCounter = 1;

  @override
  Future<CustomerProfile> getProfile(String uid) async {
    if (_currentProfile != null && _currentProfile!.uid == uid) {
      return _currentProfile!;
    }
    final profile = CustomerProfile(
      uid: uid,
      displayName: '',
      email: '',
      avatarUrl: null,
      addresses: List.unmodifiable(_addresses),
    );
    _currentProfile = profile;
    return profile;
  }

  @override
  Future<void> updateProfile(CustomerProfile profile) async {
    _currentProfile = profile;
  }

  // ── Address CRUD ─────────────────────────────────────────────────────────────

  @override
  Future<List<DeliveryAddress>> getAddresses(String uid) async {
    return List.unmodifiable(_addresses);
  }

  @override
  Future<DeliveryAddress> addAddress(
    String uid,
    DeliveryAddress address,
  ) async {
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
    _addresses.removeWhere((a) => a.addressId == addressId);
    // If we deleted the default and there are others, promote the first one.
    if (_addresses.isNotEmpty && !_addresses.any((a) => a.isDefault)) {
      _addresses[0] = _addresses[0].copyWith(isDefault: true);
    }
  }

  @override
  Future<void> setDefaultAddress(String uid, String addressId) async {
    for (var i = 0; i < _addresses.length; i++) {
      _addresses[i] = _addresses[i].copyWith(
        isDefault: _addresses[i].addressId == addressId,
      );
    }
  }
}
