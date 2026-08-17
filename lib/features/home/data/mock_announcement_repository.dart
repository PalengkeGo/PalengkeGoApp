import 'package:palengkego/features/home/domain/announcement_repository.dart';
import 'package:palengkego/features/home/domain/system_announcement.dart';

class MockAnnouncementRepository implements AnnouncementRepository {
  static final List<SystemAnnouncement> _announcements = [
    SystemAnnouncement(
      announcementId: 'ann-1',
      title: '🎉 Grand Opening Sale!',
      body:
          'Visit PalengkeGo this weekend for exclusive discounts on fresh produce. '
          'Select stalls offer up to 30% off!',
      targetAudience: AnnouncementAudience.all,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      expiresAt: DateTime.now().add(const Duration(days: 6)),
    ),
    SystemAnnouncement(
      announcementId: 'ann-2',
      title: '⏰ New Market Hours',
      body:
          'Starting August 1, the Naga Public Market will open at 5:00 AM '
          'and close at 8:00 PM daily.',
      targetAudience: AnnouncementAudience.all,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    SystemAnnouncement(
      announcementId: 'ann-3',
      title: '📋 KYC Renewal Reminder',
      body:
          'All stallholders must renew their stall permits before September 30. '
          'Submit your documents through the PalengkeGo app.',
      targetAudience: AnnouncementAudience.stallholders,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      expiresAt: DateTime(DateTime.now().year, 9, 30),
    ),
    SystemAnnouncement(
      announcementId: 'ann-4',
      title: '🚚 Delivery Now Available!',
      body:
          'Fresh market products can now be delivered straight to your door. '
          'Browse participating stalls in the Market tab.',
      targetAudience: AnnouncementAudience.customers,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];

  @override
  Future<List<SystemAnnouncement>> getActiveAnnouncements(String role) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _announcements.where((a) {
      if (!a.isActive) return false;
      return a.targetAudience == AnnouncementAudience.all ||
          (role == 'customers' &&
              a.targetAudience == AnnouncementAudience.customers) ||
          (role == 'stallholders' &&
              a.targetAudience == AnnouncementAudience.stallholders);
    }).toList();
  }
}
