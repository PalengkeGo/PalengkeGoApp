import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/home/data/firebase_announcement_repository.dart';
import 'package:palengkego/features/home/data/mock_announcement_repository.dart';
import 'package:palengkego/features/home/domain/announcement_repository.dart';
import 'package:palengkego/features/home/domain/system_announcement.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  final firebaseEnabled = ref.watch(firebaseEnabledProvider);
  if (firebaseEnabled) {
    final firestore = ref.watch(firestoreProvider);
    return FirebaseAnnouncementRepository(firestore);
  }
  return MockAnnouncementRepository();
});

final activeAnnouncementsProvider = FutureProvider<List<SystemAnnouncement>>((
  ref,
) async {
  final repository = ref.watch(announcementRepositoryProvider);
  final authFuture = ref.watch(authStateProvider.future);
  final user = await authFuture;
  // Role strings match the AnnouncementAudience enum names used by both the
  // mock filter and the Firestore targetAudience field written by the admin portal.
  final role = user?.isVendor == true ? 'stallholders' : 'customers';
  return repository.getActiveAnnouncements(role);
});
