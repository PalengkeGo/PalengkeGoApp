import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/features/home/data/supabase_announcement_repository.dart';
import 'package:palengkego/features/home/data/mock_announcement_repository.dart';
import 'package:palengkego/features/home/domain/announcement_repository.dart';
import 'package:palengkego/features/home/domain/system_announcement.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  final firebaseEnabled = ref.watch(firebaseEnabledProvider);
  if (firebaseEnabled) {
    return SupabaseAnnouncementRepository();
  }
  return MockAnnouncementRepository();
});

final activeAnnouncementsProvider = FutureProvider<List<SystemAnnouncement>>((
  ref,
) async {
  ref.watch(dataRefreshSignal);
  final repository = ref.watch(announcementRepositoryProvider);
  final user = ref.watch(authProvider);
  // Role strings match the AnnouncementAudience enum names used by both the
  // mock filter and the Firestore targetAudience field written by the admin portal.
  final isVendor = user?.isVendor == true;
  final role = isVendor ? 'stallholders' : 'customers';
  final announcements = await repository.getActiveAnnouncements(role);

  final notifService = ref.read(notificationServiceProvider);
  for (final announcement in announcements) {
    final target = announcement.targetAudience == AnnouncementAudience.all
        ? NotificationTarget.both
        : (announcement.targetAudience == AnnouncementAudience.stallholders
              ? NotificationTarget.vendor
              : NotificationTarget.customer);
    await notifService.onNewAnnouncement(
      announcementId: announcement.announcementId,
      title: announcement.title,
      body: announcement.body,
      target: target,
    );
  }

  return announcements;
});
