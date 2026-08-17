import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/home/domain/system_announcement.dart';

void main() {
  group('SystemAnnouncement.isActive', () {
    test('announcement without an expiry is always active', () {
      final announcement = SystemAnnouncement(
        announcementId: 'ann',
        title: 'T',
        body: 'B',
        targetAudience: AnnouncementAudience.all,
        createdAt: DateTime(2026, 8, 1),
      );

      expect(announcement.isActive, isTrue);
    });

    test('announcement with a future expiry is active', () {
      final announcement = SystemAnnouncement(
        announcementId: 'ann',
        title: 'T',
        body: 'B',
        targetAudience: AnnouncementAudience.all,
        createdAt: DateTime(2026, 8, 1),
        expiresAt: DateTime.now().add(const Duration(days: 5)),
      );

      expect(announcement.isActive, isTrue);
    });

    test('announcement with a past expiry is inactive', () {
      final announcement = SystemAnnouncement(
        announcementId: 'ann',
        title: 'T',
        body: 'B',
        targetAudience: AnnouncementAudience.all,
        createdAt: DateTime(2026, 8, 1),
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(announcement.isActive, isFalse);
    });
  });

  group('SystemAnnouncement.fromFirestore', () {
    test('parses title, body, audience, timestamps and image URL', () {
      final announcement = SystemAnnouncement.fromFirestore({
        'title': 'New Hours',
        'body': 'Open 5 AM daily.',
        'imageUrl': 'https://example.com/banner.png',
        'targetAudience': 'stallholders',
        'createdAt': '2026-08-01T08:00:00.000',
        'expiresAt': '2026-09-01T08:00:00.000',
      }, id: 'ann-9');

      expect(announcement.announcementId, 'ann-9');
      expect(announcement.title, 'New Hours');
      expect(announcement.body, 'Open 5 AM daily.');
      expect(announcement.imageUrl, 'https://example.com/banner.png');
      expect(announcement.targetAudience, AnnouncementAudience.stallholders);
      expect(announcement.createdAt, DateTime(2026, 8, 1, 8));
      expect(announcement.expiresAt, DateTime(2026, 9, 1, 8));
    });

    test('falls back to a default audience when the field is missing', () {
      final announcement = SystemAnnouncement.fromFirestore({
        'title': 'T',
        'body': 'B',
      }, id: 'ann-10');

      expect(announcement.targetAudience, AnnouncementAudience.all);
      expect(announcement.expiresAt, isNull);
      expect(announcement.imageUrl, isNull);
    });
  });

  group('SystemAnnouncement.toJson', () {
    test('serializes fields and omits null imageUrl and expiresAt', () {
      final announcement = SystemAnnouncement(
        announcementId: 'ann-11',
        title: 'T',
        body: 'B',
        targetAudience: AnnouncementAudience.customers,
        createdAt: DateTime(2026, 8, 1),
      );

      final json = announcement.toJson();
      expect(json['title'], 'T');
      expect(json['body'], 'B');
      expect(json['targetAudience'], 'customers');
      expect(json['createdAt'], '2026-08-01T00:00:00.000');
      expect(json.containsKey('imageUrl'), isFalse);
      expect(json.containsKey('expiresAt'), isFalse);
    });
  });
}
