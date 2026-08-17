import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/profile/data/firebase_profile_repository.dart';
import 'package:palengkego/features/profile/data/mock_profile_repository.dart';
import 'package:palengkego/features/profile/data/profile_repository.dart';
import 'package:palengkego/features/profile/domain/customer_profile.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final firebaseEnabled = ref.watch(firebaseEnabledProvider);
  if (firebaseEnabled) {
    final firestore = ref.watch(firestoreProvider);
    return FirebaseProfileRepository(firestore);
  }
  return MockProfileRepository();
});

final currentProfileProvider = FutureProvider<CustomerProfile?>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final authFuture = ref.watch(authStateProvider.future);
  final authState = await authFuture;
  if (authState == null) {
    return null; // Not logged in
  }

  return repository.getProfile(authState.uid);
});

/// All saved addresses for the currently logged-in customer.
final addressesProvider = FutureProvider<List<DeliveryAddress>>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final authFuture = ref.watch(authStateProvider.future);
  final authState = await authFuture;
  if (authState == null) return [];
  return repository.getAddresses(authState.uid);
});
