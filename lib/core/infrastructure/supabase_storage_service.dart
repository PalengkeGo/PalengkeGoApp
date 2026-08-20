import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';

/// Central file uploads -> Supabase Storage, returning the URL to persist in
/// Firestore. Buckets must be created manually in the Supabase dashboard:
/// `stalls` and `profiles` (public reads), `kyc` and `license` (private).
class SupabaseStorageService {
  SupabaseStorageService(this._client);

  final SupabaseClient? _client;

  static const stallsBucket = 'stalls';
  static const profilesBucket = 'profiles';
  static const kycBucket = 'kyc';
  static const licenseBucket = 'license';

  /// Buckets whose objects are publicly readable (no signed URL needed).
  static const _publicBuckets = {stallsBucket, profilesBucket};

  /// Private buckets get a signed URL. 30 days covers a full KYC/renewal
  /// review cycle; pony tail: signed URLs expire — if review ever takes
  /// longer, re-issue the URL on read instead of extending this.
  static const _signedUrlExpirySeconds = 30 * 24 * 60 * 60;

  /// Uploads [file] to `{bucket}/{path}` and returns the URL to store in
  /// Firestore (public URL for public buckets, signed URL for private ones).
  ///
  /// Returns null when Supabase is not configured (mock/dev mode without
  /// dart-defines) — callers may fall back to the local path then. Throws
  /// when configured but the upload itself fails, so callers can surface it.
  Future<String?> uploadFile({
    required String bucket,
    required String path,
    required File file,
  }) async {
    final client = _client;
    if (client == null) return null;

    await client.storage.from(bucket).upload(path, file);

    final storage = client.storage.from(bucket);
    if (_publicBuckets.contains(bucket)) {
      return storage.getPublicUrl(path);
    }
    return storage.createSignedUrl(path, _signedUrlExpirySeconds);
  }

  /// Sanitized file extension for object naming (e.g. `.jpg`, `.pdf`).
  static String extensionOf(File file) {
    final name = file.path.split('/').last.split('#').last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '.bin';
    var ext = name.substring(dot).toLowerCase();
    if (!RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(ext)) return '.bin';
    return ext;
  }

  /// Unique-ish object name: `{prefix}_{millis}{ext}`. Timestamp collision
  /// within the same screen is practically impossible for human-paced picks.
  static String objectName(String prefix, File file) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}${extensionOf(file)}';
}

final supabaseStorageServiceProvider = Provider<SupabaseStorageService>((ref) {
  return SupabaseStorageService(ref.watch(supabaseClientProvider));
});