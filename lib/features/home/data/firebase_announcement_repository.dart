import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:palengkego/features/home/domain/announcement_repository.dart';
import 'package:palengkego/features/home/domain/system_announcement.dart';

/// Firestore implementation of [AnnouncementRepository].
///
/// Collection: `systemAnnouncements/{announcementId}`
///
/// Written exclusively by the Admin Web portal.
/// This repo is read-only from the Flutter app's perspective.
class FirebaseAnnouncementRepository implements AnnouncementRepository {
  FirebaseAnnouncementRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<SystemAnnouncement>> getActiveAnnouncements(String role) async {
    final now = Timestamp.now();

    // Base query: targetAudience == 'all' OR matches the user's role.
    // Firestore doesn't support OR across different fields, so we run
    // two queries and merge client-side (both are tiny reads).
    final allSnap = await _firestore
        .collection('systemAnnouncements')
        .where('targetAudience', isEqualTo: 'all')
        .get();

    final roleSnap = await _firestore
        .collection('systemAnnouncements')
        .where('targetAudience', isEqualTo: role)
        .get();

    final seen = <String>{};
    final results = <SystemAnnouncement>[];

    for (final doc in [...allSnap.docs, ...roleSnap.docs]) {
      if (seen.contains(doc.id)) continue;
      seen.add(doc.id);

      final a = SystemAnnouncement.fromFirestore(doc.data(), id: doc.id);

      // Client-side expiry filter (Firestore doesn't support null OR > now).
      final expiresAt = doc.data()['expiresAt'];
      if (expiresAt != null && (expiresAt as Timestamp).compareTo(now) <= 0) {
        continue;
      }

      results.add(a);
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }
}
