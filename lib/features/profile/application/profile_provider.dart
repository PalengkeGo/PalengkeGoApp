import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/profile/data/mock_profile_repository.dart';
import 'package:palengkego/features/profile/data/profile_repository.dart';
import 'package:palengkego/features/profile/domain/customer_profile.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return MockProfileRepository();
});

final currentProfileProvider = FutureProvider<CustomerProfile?>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) {
    return null; // Not logged in
  }

  final repository = ref.watch(profileRepositoryProvider);
  CustomerProfile profile;
  try {
    profile = await repository.getProfile(user.uid);
  } catch (_) {
    profile = CustomerProfile(
      uid: user.uid,
      displayName: user.displayName ?? '',
      email: user.email,
    );
  }

  DateTime? joinedAt = profile.joinedAt;
  if (joinedAt == null && ref.read(firebaseEnabledProvider)) {
    joinedAt =
        ref.read(firebaseAuthProvider).currentUser?.metadata.creationTime;
  }

  final displayName = profile.displayName.isNotEmpty
      ? profile.displayName
      : (user.displayName?.isNotEmpty == true
          ? user.displayName!
          : (user.email.isNotEmpty
              ? user.email.split('@').first
              : 'Customer'));

  final email = profile.email.isNotEmpty ? profile.email : user.email;
  final phoneNumber = profile.phoneNumber?.isNotEmpty == true
      ? profile.phoneNumber
      : user.phoneNumber;
  final avatarUrl = profile.avatarUrl ?? user.profilePhoto;

  return profile.copyWith(
    uid: user.uid,
    displayName: displayName,
    email: email,
    phoneNumber: phoneNumber,
    avatarUrl: avatarUrl,
    joinedAt: joinedAt,
  );
});

/// All saved addresses for the currently logged-in customer.
final addressesProvider = FutureProvider<List<DeliveryAddress>>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final user = ref.watch(authProvider);
  if (user == null) return [];
  return repository.getAddresses(user.uid);
});
