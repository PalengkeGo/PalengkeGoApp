/// Target audience for a system announcement.
enum AnnouncementAudience { all, customers, stallholders }

/// A system-wide announcement published by an admin on the Admin Web portal.
///
/// Matches the SYSTEM_ANNOUNCEMENTS ERD entity.
/// Collection path: `systemAnnouncements/{announcementId}`
///
/// The home screen reads active, non-expired announcements for the current
/// user's role and displays them in the announcement card carousel.
class SystemAnnouncement {
  const SystemAnnouncement({
    required this.announcementId,
    required this.title,
    required this.body,
    required this.targetAudience,
    required this.createdAt,
    this.expiresAt,
    this.imageUrl,
  });

  final String announcementId;
  final String title;
  final String body;

  /// Optional image banner to show in the carousel
  final String? imageUrl;

  /// Who should see this announcement.
  final AnnouncementAudience targetAudience;

  final DateTime createdAt;

  /// If set, the announcement stops appearing after this timestamp.
  final DateTime? expiresAt;

  /// Whether this announcement is still active (not yet expired).
  bool get isActive {
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }

  factory SystemAnnouncement.fromFirestore(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return SystemAnnouncement(
      announcementId: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      targetAudience: AnnouncementAudience.values.firstWhere(
        (e) => e.name == data['targetAudience'],
        orElse: () => AnnouncementAudience.all,
      ),
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : DateTime.now(),
      expiresAt: data['expiresAt'] != null
          ? DateTime.parse(data['expiresAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'targetAudience': targetAudience.name,
      'createdAt': createdAt.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    };
  }
}
