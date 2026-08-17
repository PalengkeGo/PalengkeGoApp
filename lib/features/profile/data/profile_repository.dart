import 'package:palengkego/features/profile/domain/customer_profile.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

abstract class ProfileRepository {
  Future<CustomerProfile> getProfile(String uid);
  Future<void> updateProfile(CustomerProfile profile);

  // ── Address CRUD ────────────────────────────────────────────────────────────
  /// All saved delivery addresses for the given customer.
  Future<List<DeliveryAddress>> getAddresses(String uid);

  /// Persist a new address. Returns the saved object with its [addressId] set.
  Future<DeliveryAddress> addAddress(String uid, DeliveryAddress address);

  /// Update an existing address (matched by [DeliveryAddress.addressId]).
  Future<void> updateAddress(String uid, DeliveryAddress address);

  /// Remove an address by ID.
  Future<void> deleteAddress(String uid, String addressId);

  /// Mark one address as default, clearing the flag on all others.
  Future<void> setDefaultAddress(String uid, String addressId);
}
