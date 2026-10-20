import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/user_report.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository();
});

final userReportsProvider =
    FutureProvider.family<List<UserReport>, String>((ref, userId) async {
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getUserReports(userId);
});

class ReportsRepository {
  static const _cacheKey = 'palengkego_user_reports_cache';

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Submits a user report to Supabase `reports` table and caches locally.
  Future<String?> submitReport(UserReport report) async {
    final sb = _supabase;
    String? sbError;

    if (sb != null) {
      try {
        await sb.from('reports').insert(report.toJson());
      } catch (e) {
        debugPrint('[reports] Supabase report insert failed: $e');
        sbError = e.toString();
      }
    }

    // Always cache locally so reports and resolutions remain visible to user
    await _saveToLocalCache(report);
    return sbError;
  }

  /// Retrieves all reports submitted by a specific user.
  Future<List<UserReport>> getUserReports(
    String userId, {
    String? email,
  }) async {
    final localList = await _loadFromLocalCache(userId: userId, email: email);
    final sb = _supabase;
    if (sb == null) return localList;

    if ((userId.isEmpty) && (email == null || email.isEmpty)) {
      return localList;
    }

    try {
      var query = sb.from('reports').select('*');
      if (userId.isNotEmpty && email != null && email.isNotEmpty) {
        query = query.or('user_id.eq.$userId,reporter_email.eq.$email');
      } else if (userId.isNotEmpty) {
        query = query.eq('user_id', userId);
      } else if (email != null && email.isNotEmpty) {
        query = query.eq('reporter_email', email);
      }

      final response = await query.order('created_at', ascending: false);
      final remoteList = (response as List<dynamic>? ?? []).map((item) {
        return UserReport.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();

      // Merge remote list with local cache
      final mergedMap = <String, UserReport>{};
      for (final report in localList) {
        mergedMap[report.id] = report;
      }
      for (final report in remoteList) {
        mergedMap[report.id] = report;
      }

      final merged = mergedMap.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Persist latest merged statuses (including Admin resolutions) to local cache
      await _saveAllToLocalCache(merged);
      return merged;
    } catch (e) {
      debugPrint('[reports] Supabase fetch user reports failed: $e');
      return localList;
    }
  }

  Future<void> _saveAllToLocalCache(List<UserReport> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = reports.map((r) => r.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[reports] Failed to save all to local cache: $e');
    }
  }

  Future<void> _saveToLocalCache(UserReport report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString(_cacheKey);
      final list = <Map<String, dynamic>>[];
      if (existingJson != null && existingJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(existingJson) as List<dynamic>;
          for (final item in decoded) {
            final m = Map<String, dynamic>.from(item as Map);
            if (m['id'] != report.id) {
              list.add(m);
            }
          }
        } catch (_) {}
      }
      list.insert(0, report.toJson());
      await prefs.setString(_cacheKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[reports] Failed to save local cache: $e');
    }
  }

  Future<List<UserReport>> _loadFromLocalCache({
    String? userId,
    String? email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      final result = <UserReport>[];
      for (final item in decoded) {
        final report =
            UserReport.fromJson(Map<String, dynamic>.from(item as Map));
        if (userId != null &&
            userId.isNotEmpty &&
            report.userId == userId) {
          result.add(report);
        } else if (email != null &&
            email.isNotEmpty &&
            report.reporterEmail == email) {
          result.add(report);
        } else if ((userId == null || userId.isEmpty) &&
            (email == null || email.isEmpty)) {
          result.add(report);
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Subscribes to realtime updates for a user's reports.
  /// The instant the admin updates the status or adds a resolution note,
  /// [onUpdate] is invoked with the updated report.
  RealtimeChannel? subscribeToUserReports({
    required String userId,
    required void Function(UserReport report) onUpdate,
  }) {
    final sb = _supabase;
    if (sb == null || userId.isEmpty) return null;

    final channel = sb.channel('user-reports-$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'reports',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        try {
          final record = payload.newRecord;
          if (record.isEmpty) return;
          final updatedReport = UserReport.fromJson(record);
          _saveToLocalCache(updatedReport);
          onUpdate(updatedReport);
        } catch (e) {
          debugPrint('[reports] Realtime user report error: $e');
        }
      },
    );
    channel.subscribe();
    return channel;
  }
}
