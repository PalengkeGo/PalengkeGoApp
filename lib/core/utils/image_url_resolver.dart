import 'package:palengkego/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves raw image strings (Google Drive share links, Supabase storage paths,
/// relative storage URLs, or standard web URLs) into a direct browser/app-loadable URL.
String? resolveImageUrl(
  String? raw, {
  String? supabaseUrl,
  SupabaseClient? client,
}) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  // 1. Google Drive view/open/uc links -> direct CDN image endpoint (lh3.googleusercontent.com)
  // which provides raw image bytes with Access-Control-Allow-Origin: * for web rendering.
  final driveFileMatch = RegExp(
    r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)',
  ).firstMatch(trimmed);
  if (driveFileMatch != null) {
    final fileId = driveFileMatch.group(1);
    return 'https://lh3.googleusercontent.com/d/$fileId';
  }

  final driveIdParamMatch = RegExp(
    r'drive\.google\.com/(?:open|uc)\?(?:[^&]*&)*id=([a-zA-Z0-9_-]+)',
  ).firstMatch(trimmed);
  if (driveIdParamMatch != null) {
    final fileId = driveIdParamMatch.group(1);
    return 'https://lh3.googleusercontent.com/d/$fileId';
  }

  // 2. Already an absolute web or data/blob/asset URL
  if (trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('blob:') ||
      trimmed.startsWith('data:') ||
      trimmed.startsWith('assets/')) {
    return trimmed;
  }

  // 3. Supabase Storage relative paths or storage bucket references
  String baseUrl = supabaseUrl ?? '';
  if (baseUrl.isEmpty) {
    try {
      baseUrl = AppConfig.load().supabaseUrl;
    } catch (_) {}
  }
  if (baseUrl.endsWith('/')) {
    baseUrl = baseUrl.substring(0, baseUrl.length - 1);
  }

  if (trimmed.startsWith('/storage/v1/object/public/')) {
    return baseUrl.isNotEmpty ? '$baseUrl$trimmed' : trimmed;
  }
  if (trimmed.startsWith('storage/v1/object/public/')) {
    return baseUrl.isNotEmpty ? '$baseUrl/$trimmed' : trimmed;
  }

  final activeClient = client ??
      () {
        try {
          return Supabase.instance.client;
        } catch (_) {
          return null;
        }
      }();

  if (trimmed.contains('/')) {
    final slashIndex = trimmed.indexOf('/');
    final bucket = trimmed.substring(0, slashIndex);
    final path = trimmed.substring(slashIndex + 1);
    if (activeClient != null) {
      try {
        return activeClient.storage.from(bucket).getPublicUrl(path);
      } catch (_) {}
    }
    if (baseUrl.isNotEmpty) {
      return '$baseUrl/storage/v1/object/public/$bucket/$path';
    }
  } else {
    // Bare filename e.g. "tuna_kilawin.png" -> default to 'recipes' bucket
    if (activeClient != null) {
      try {
        return activeClient.storage.from('recipes').getPublicUrl(trimmed);
      } catch (_) {}
    }
    if (baseUrl.isNotEmpty) {
      return '$baseUrl/storage/v1/object/public/recipes/$trimmed';
    }
  }

  return trimmed;
}
