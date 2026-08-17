import 'package:palengkego/features/home/domain/system_announcement.dart';

/// Contract for reading system-wide announcements published by the admin portal.
abstract class AnnouncementRepository {
  /// Returns all active (non-expired) announcements visible to the given role.
  /// [role] should be 'customers', 'stallholders', or 'admin' — matching the
  /// AnnouncementAudience enum names written to Firestore by the admin portal.
  Future<List<SystemAnnouncement>> getActiveAnnouncements(String role);
}
