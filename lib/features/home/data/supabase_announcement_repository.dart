import 'package:palengkego/features/home/domain/announcement_repository.dart';
import 'package:palengkego/features/home/domain/system_announcement.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [AnnouncementRepository].
///
/// Table: `system_announcements`
///
/// Read-only from the Flutter app's perspective. Written exclusively by
/// the Admin Web portal.
class SupabaseAnnouncementRepository implements AnnouncementRepository {
  SupabaseAnnouncementRepository();

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  Future<List<SystemAnnouncement>> getActiveAnnouncements(String role) async {
    final now = DateTime.now().toIso8601String();

    // Query announcements where targetAudience is 'all' OR matches the role
    // Since Supabase doesn't support OR across different fields easily,
    // we'll run two queries and merge client-side (both are tiny reads).
    final allResponse = await _supabase
        .from('system_announcements')
        .select('*')
        .eq('target_audience', 'all')
        .or('expires_at.is.null,expires_at.gt.$now');

    final roleResponse = await _supabase
        .from('system_announcements')
        .select('*')
        .eq('target_audience', role)
        .or('expires_at.is.null,expires_at.gt.$now');

    final allData = (allResponse as List<dynamic>? ?? []);
    final roleData = (roleResponse as List<dynamic>? ?? []);

    final seen = <String>{};
    final results = <SystemAnnouncement>[];

    for (final item in [...allData, ...roleData]) {
      final id = item['id'] as String? ?? '';
      if (seen.contains(id)) continue;
      seen.add(id);

      final announcement = SystemAnnouncement.fromFirestore(
        item as Map<String, dynamic>,
        id: id,
      );
      results.add(announcement);
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }
}