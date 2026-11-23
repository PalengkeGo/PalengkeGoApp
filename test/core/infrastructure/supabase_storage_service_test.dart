import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:palengkego/core/infrastructure/supabase_storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();
}

class _FakeUser extends Fake implements User {
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'firebase-token';
}

void main() {
  test(
    'uploadFileDetailed signs and PUTs directly without a failing direct-upload preflight',
    () async {
      final tempDir = Directory.systemTemp.createTempSync('storage_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final file = File('${tempDir.path}/avatar.jpg')
        ..writeAsBytesSync([1, 2, 3, 4]);

      final requestedPaths = <String>[];
      final supabaseClient = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: MockClient((request) async {
          requestedPaths.add('${request.method} ${request.url}');
          return http.Response('Unexpected SDK storage call', 500);
        }),
      );
      addTearDown(supabaseClient.dispose);

      final httpClient = MockClient((request) async {
        requestedPaths.add('${request.method} ${request.url}');
        if (request.url.path == '/functions/v1/storage-upload') {
          expect(request.headers['Authorization'], 'Bearer firebase-token');
          return http.Response(
            jsonEncode({
              'uploadUrl': 'https://upload.example.test/signed-put',
              'token': 'signed-upload-token',
            }),
            200,
          );
        }
        if (request.url.toString() == 'https://upload.example.test/signed-put') {
          expect(request.method, 'PUT');
          expect(request.headers['x-supabase-upload-token'], 'signed-upload-token');
          return http.Response('', 200);
        }
        return http.Response('Unexpected URL', 500);
      });
      addTearDown(httpClient.close);

      final service = SupabaseStorageService(
        supabaseClient,
        _FakeAuth(),
        httpClient,
        supabaseUrl: 'https://example.supabase.co',
      );

      final result = await service.uploadFileDetailed(
        bucket: SupabaseStorageService.profilesBucket,
        path: 'uid-1/avatar.jpg',
        file: file,
      );

      expect(
        requestedPaths,
        [
          'POST https://example.supabase.co/functions/v1/storage-upload',
          'PUT https://upload.example.test/signed-put',
        ],
      );
      expect(
        result.url,
        'https://example.supabase.co/storage/v1/object/public/profiles/uid-1/avatar.jpg',
      );
      expect(result.path, 'uid-1/avatar.jpg');
    },
  );
}
