import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/profile/data/mock_profile_repository.dart';
import 'package:palengkego/features/profile/data/profile_repository.dart';
import 'package:palengkego/features/profile/domain/customer_profile.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return MockProfileRepository();
});

final currentProfileProvider = FutureProvider<CustomerProfile?>((ref) async {
  ref.watch(dataRefreshSignal);
  final user = ref.watch(authProvider);
  if (user == null) {
    return null; // Not logged in
  }

  final client = ref.watch(supabaseClientProvider);
  if (client != null) {
    final row = await client
        .from('users')
        .select()
        .eq('user_id', user.uid)
        .single();
    return CustomerProfile(
      uid: user.uid,
      displayName: row['full_name'] as String? ?? '',
      email: row['email'] as String? ?? user.email,
      phoneNumber: row['phone_number'] as String?,
      avatarUrl: row['profile_photo'] as String?,
      joinedAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
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
    joinedAt = ref
        .read(firebaseAuthProvider)
        .currentUser
        ?.metadata
        .creationTime;
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
  String? avatarUrl = profile.avatarUrl ?? user.profilePhoto;

  if (avatarUrl == null || avatarUrl.isEmpty) {
    final client = ref.read(supabaseClientProvider);
    if (client != null) {
      try {
        final query = client.from('users').select('profile_photo');
        final row = user.uid.isNotEmpty
            ? await query
                  .or('user_id.eq.${user.uid},email.eq.${user.email}')
                  .maybeSingle()
            : await query.eq('email', user.email).maybeSingle();
        if (row != null && row['profile_photo'] != null) {
          avatarUrl = row['profile_photo'] as String?;
        }
      } catch (_) {}
    }
  }

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
  if (ref.watch(supabaseClientProvider) != null) {
    return ref.watch(preferencesProvider).savedAddresses;
  }
  final repository = ref.watch(profileRepositoryProvider);
  final user = ref.watch(authProvider);
  if (user == null) return [];
  return repository.getAddresses(user.uid);
});
