import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';

/// Central file uploads/reads → Supabase Storage via the trusted edge
/// functions (`storage-upload` / `storage-sign`).
///
/// SECURITY (audit 2026-09-13 C1 + M1): the anon key has NO INSERT or SELECT
/// policies on ANY bucket anymore. Uploads are authorized by the
/// `storage-upload` edge function — it verifies the caller's Firebase ID
/// token, enforces `{uid}/...` path ownership and per-bucket extension
/// allowlists server-side, and returns a short-lived signed upload URL; the
/// file bytes then go straight from this device to Storage (the bucket's
/// file_size_limit / allowed_mime_types still cap the PUT at the Storage
/// API). Private-bucket reads are minted by `storage-sign` (owner or admin)
/// and expire in 1 hour — no more 30-day bearer URLs persisted in Firestore.
///
/// PERSISTENCE RULE: for private buckets, store the returned [UploadResult.path]
/// in Firestore (durable). The returned url is a 1-hour display URL — never
/// persist it.
class SupabaseStorageService {
  SupabaseStorageService(
    this._client,
    this._auth,
    this._http, {
    String? supabaseUrl,
  }) : _supabaseUrl = supabaseUrl;

  final SupabaseClient? _client;
  final FirebaseAuth? _auth;
  final http.Client _http;
  final String? _supabaseUrl;

  String? get _cleanSupabaseUrl {
    final url = _supabaseUrl?.trim();
    if (url == null || url.isEmpty) return null;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static const stallsBucket = 'stalls';
  static const profilesBucket = 'profiles';
  static const kycBucket = 'kyc';
  static const licenseBucket = 'license';

  /// Buckets whose objects are publicly readable via /object/public/ URLs
  /// (no RLS needed — public by bucket flag). `kyc` and `license` are
  /// private: reads go through [mintSignedUrl].
  static const _publicBuckets = {stallsBucket, profilesBucket};

  /// Uploads [file] to `{bucket}/{path}` through the trusted edge function.
  ///
  /// Returns null url when Supabase is not configured (mock/dev mode) —
  /// callers may fall back to the local path then. Throws when configured
  /// but the upload fails, so callers can surface it.
  Future<({String? url, String path})> uploadFileDetailed({
    required String bucket,
    required String path,
    required File file,
  }) async {
    final client = _client;
    final supabaseUrl = _cleanSupabaseUrl;
    if (client == null || supabaseUrl == null) return (url: null, path: path);

    final user = _auth?.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to upload files.');
    }
    final idToken = await user.getIdToken();

    // 1. Ask the trusted edge function to authorize and mint the upload URL.
    final signRes = await _http.post(
      Uri.parse('$supabaseUrl/functions/v1/storage-upload'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'bucket': bucket, 'path': path}),
    );
    if (signRes.statusCode != 200) {
      throw Exception('Upload authorization failed (${signRes.statusCode}).');
    }
    final signBody = jsonDecode(signRes.body) as Map<String, dynamic>;
    final uploadUrl = signBody['uploadUrl'] as String?;
    final uploadToken = signBody['token'] as String?;
    if (uploadUrl == null || uploadToken == null) {
      throw Exception('Upload authorization returned no signed URL.');
    }

    // 2. Upload the bytes straight to Storage with the one-time token.
    final bytes = await file.readAsBytes();
    final upRes = await _http.put(
      Uri.parse(uploadUrl),
      headers: {
        'x-supabase-upload-token': uploadToken,
        'Content-Type': _contentTypeFor(path),
      },
      body: bytes,
    );
    if (upRes.statusCode != 200) {
      throw Exception('Upload failed (${upRes.statusCode}).');
    }

    // 3. Display URL: public URL for public buckets; 1-hour signed URL for
    //    private buckets (persist the PATH, not this URL).
    final url = _publicBuckets.contains(bucket)
        ? client.storage.from(bucket).getPublicUrl(path)
        : await mintSignedUrl(bucket: bucket, path: path);
    return (url: url, path: path);
  }

  /// Convenience wrapper matching the pre-hardening contract: returns only
  /// the display URL. Private-bucket callers should prefer
  /// [uploadFileDetailed] so they can persist the durable path too.
  Future<String?> uploadFile({
    required String bucket,
    required String path,
    required File file,
  }) async {
    final result = await uploadFileDetailed(
      bucket: bucket,
      path: path,
      file: file,
    );
    return result.url;
  }

  /// Mints a 1-hour read URL for a private-bucket object via the trusted
  /// `storage-sign` edge function (owner or admin). Returns null when
  /// Supabase is unconfigured or the mint fails — callers may hide the
  /// document preview then.
  Future<String?> mintSignedUrl({
    required String bucket,
    required String path,
  }) async {
    final client = _client;
    final supabaseUrl = _cleanSupabaseUrl;
    if (client == null || supabaseUrl == null) return null;
    final user = _auth?.currentUser;
    if (user == null) return null;

    final idToken = await user.getIdToken();
    final res = await _http.post(
      Uri.parse('$supabaseUrl/functions/v1/storage-sign'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'bucket': bucket, 'path': path}),
    );
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['url'] as String?;
  }

  /// Content type for the Storage PUT, derived from the object extension.
  /// The bucket's allowed_mime_types reject mismatches server-side.
  static String _contentTypeFor(String path) {
    switch (path.split('.').last.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
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
  // FirebaseAuth.instance throws in mock/demo mode (no Firebase app) — the
  // service tolerates a null auth there because uploads short-circuit on a
  // null Supabase client first.
  FirebaseAuth? auth;
  try {
    auth = FirebaseAuth.instance;
  } catch (_) {
    auth = null;
  }
  final config = ref.watch(appConfigProvider);
  return SupabaseStorageService(
    ref.watch(supabaseClientProvider),
    auth,
    http.Client(),
    supabaseUrl: config.supabaseUrl,
  );
});
