import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:palengkego/features/profile/data/profile_repository.dart';
import 'package:palengkego/features/profile/domain/customer_profile.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

/// Firestore implementation of [ProfileRepository].
///
/// Collections:
///   `customerProfiles/{uid}`
///   `customerProfiles/{uid}/addresses/{addressId}`
class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) =>
      _firestore.collection('customerProfiles').doc(uid);

  CollectionReference<Map<String, dynamic>> _addressesRef(String uid) =>
      _profileRef(uid).collection('addresses');

  // ── Profile ─────────────────────────────────────────────────────────────────

  @override
  Future<CustomerProfile> getProfile(String uid) async {
    final snap = await _profileRef(uid).get();
    if (!snap.exists) {
      return CustomerProfile(uid: uid, displayName: '', email: '');
    }
    return CustomerProfile.fromFirestore(snap.data()!);
  }

  @override
  Future<void> updateProfile(CustomerProfile profile) async {
    await _profileRef(
      profile.uid,
    ).set(profile.toFirestore(), SetOptions(merge: true));
  }

  // ── Address CRUD ─────────────────────────────────────────────────────────────

  @override
  Future<List<DeliveryAddress>> getAddresses(String uid) async {
    final snap = await _addressesRef(
      uid,
    ).orderBy('isDefault', descending: true).get();
    return snap.docs
        .map((d) => DeliveryAddress.fromFirestore(d.data(), id: d.id))
        .toList();
  }

  @override
  Future<DeliveryAddress> addAddress(
    String uid,
    DeliveryAddress address,
  ) async {
    // If this will be the default, clear existing default first.
    if (address.isDefault) await _clearDefault(uid);

    final ref = _addressesRef(uid).doc();
    await ref.set(address.toFirestore());
    return address.copyWith(addressId: ref.id);
  }

  @override
  Future<void> updateAddress(String uid, DeliveryAddress address) async {
    if (address.addressId == null) return;
    if (address.isDefault) await _clearDefault(uid);
    await _addressesRef(uid)
        .doc(address.addressId)
        .set(address.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteAddress(String uid, String addressId) async {
    await _addressesRef(uid).doc(addressId).delete();
  }

  @override
  Future<void> setDefaultAddress(String uid, String addressId) async {
    await _clearDefault(uid);
    await _addressesRef(uid).doc(addressId).update({'isDefault': true});
  }

  /// Sets isDefault=false on all addresses for the given user.
  Future<void> _clearDefault(String uid) async {
    final snap = await _addressesRef(
      uid,
    ).where('isDefault', isEqualTo: true).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isDefault': false});
    }
    await batch.commit();
  }
}
