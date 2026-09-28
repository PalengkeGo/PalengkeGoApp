import 'package:palengkego/features/profile/data/profile_repository.dart';
import 'package:palengkego/features/profile/domain/customer_profile.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

class MockProfileRepository implements ProfileRepository {
  final Map<String, CustomerProfile> _profilesByUser = {};
  final Map<String, List<DeliveryAddress>> _addressesByUser = {};

  int _addressIdCounter = 1;

  @override
  Future<CustomerProfile> getProfile(String uid) async {
    if (_profilesByUser.containsKey(uid)) {
      return _profilesByUser[uid]!;
    }
    final addresses = _addressesByUser[uid] ?? const [];
    final profile = CustomerProfile(
      uid: uid,
      displayName: '',
      email: '',
      avatarUrl: null,
      addresses: List.unmodifiable(addresses),
    );
    _profilesByUser[uid] = profile;
    return profile;
  }

  @override
  Future<void> updateProfile(CustomerProfile profile) async {
    _profilesByUser[profile.uid] = profile;
  }

  // ── Address CRUD ─────────────────────────────────────────────────────────────

  @override
  Future<List<DeliveryAddress>> getAddresses(String uid) async {
    return List.unmodifiable(_addressesByUser[uid] ?? const []);
  }

  @override
  Future<DeliveryAddress> addAddress(
    String uid,
    DeliveryAddress address,
  ) async {
    final userAddresses = _addressesByUser.putIfAbsent(uid, () => []);
    final saved = address.copyWith(
      addressId: 'addr-${_addressIdCounter++}',
      isDefault: userAddresses.isEmpty ? true : address.isDefault,
    );
    if (saved.isDefault) {
      // Clear default on all others.
      for (var i = 0; i < userAddresses.length; i++) {
        if (userAddresses[i].isDefault) {
          userAddresses[i] = userAddresses[i].copyWith(isDefault: false);
        }
      }
    }
    userAddresses.add(saved);
    return saved;
  }

  @override
  Future<void> updateAddress(String uid, DeliveryAddress address) async {
    final userAddresses = _addressesByUser[uid];
    if (userAddresses != null) {
      final idx = userAddresses.indexWhere((a) => a.addressId == address.addressId);
      if (idx != -1) {
        if (address.isDefault) {
          for (var i = 0; i < userAddresses.length; i++) {
            if (userAddresses[i].isDefault) {
              userAddresses[i] = userAddresses[i].copyWith(isDefault: false);
            }
          }
        }
        userAddresses[idx] = address;
      }
    }
  }

  @override
  Future<void> deleteAddress(String uid, String addressId) async {
    final userAddresses = _addressesByUser[uid];
    if (userAddresses != null) {
      userAddresses.removeWhere((a) => a.addressId == addressId);
      // If we deleted the default and there are others, promote the first one.
      if (userAddresses.isNotEmpty && !userAddresses.any((a) => a.isDefault)) {
        userAddresses[0] = userAddresses[0].copyWith(isDefault: true);
      }
    }
  }

  @override
  Future<void> setDefaultAddress(String uid, String addressId) async {
    final userAddresses = _addressesByUser[uid];
    if (userAddresses != null) {
      for (var i = 0; i < userAddresses.length; i++) {
        userAddresses[i] = userAddresses[i].copyWith(
          isDefault: userAddresses[i].addressId == addressId,
        );
      }
    }
  }
}
