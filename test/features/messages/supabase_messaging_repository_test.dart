import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:palengkego/features/messages/data/supabase_messaging_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'chat mutations use RPCs without trusting client sender or reader roles',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        accessToken: () async => 'firebase-token',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'id': 'one',
              'sender_id': 'verified-user',
              'sender_role': 'customer',
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = SupabaseMessagingRepository(client: client);
      await repo.getOrCreateConversation(
        customerUid: 'customer',
        customerName: 'Spoofed',
        stallId: 'stall',
        stallName: 'Spoofed',
      );
      final message = await repo.sendMessage(
        conversationId: 'one',
        senderId: 'spoofed',
        senderName: 'Spoofed',
        senderRole: 'admin',
        text: 'Hello',
      );
      await repo.markAsRead(conversationId: 'one', readerRole: 'admin');
      expect(message.senderId, 'verified-user');
      expect(requests.map((r) => r.url.path), [
        '/rest/v1/rpc/chat_get_or_create',
        '/rest/v1/rpc/chat_send_message',
        '/rest/v1/rpc/chat_mark_read',
      ]);
      expect(
        requests[0].headers['accept'],
        'application/vnd.pgrst.object+json',
      );
      expect(
        requests[1].headers['accept'],
        'application/vnd.pgrst.object+json',
      );
      expect(
        requests.every(
          (r) => r.headers['authorization'] == 'Bearer firebase-token',
        ),
        isTrue,
      );
      final sendBody = jsonDecode(requests[1].body) as Map;
      expect(
        sendBody.keys,
        unorderedEquals([
          'p_conversation_id',
          'p_text',
          'p_attachment_url',
          'p_attachment_type',
        ]),
      );
      expect(jsonDecode(requests[2].body), {'p_conversation_id': 'one'});
    },
  );

  test(
    'denied reads and writes propagate instead of appearing successful',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient(
          (request) async => http.Response(
            '{"message":"Chat access denied","code":"42501"}',
            403,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      final repo = SupabaseMessagingRepository(client: client);
      await expectLater(
        repo.getMessages('other'),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        repo.markAsRead(conversationId: 'other', readerRole: 'vendor'),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        repo.sendMessage(
          conversationId: 'other',
          senderId: 'spoof',
          senderName: 'Spoof',
          senderRole: 'vendor',
          text: 'test',
        ),
        throwsA(isA<PostgrestException>()),
      );
    },
  );

  test(
    'getMessages batch-signs chat attachments once and caches signed URLs',
    () async {
      var signCalls = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        accessToken: () async => 'firebase-token',
        httpClient: MockClient((request) async {
          if (request.url.path == '/rest/v1/messages') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'm1',
                  'conversation_id': 'thread-1',
                  'sender_id': 'u1',
                  'sender_name': 'Customer',
                  'sender_role': 'customer',
                  'text': 'First photo',
                  'timestamp': '2026-11-01T10:00:00Z',
                  'is_read': true,
                  'attachment_url': 'chat-attachments/thread-1/u1/a.jpg',
                  'attachment_type': 'image',
                },
                {
                  'id': 'm2',
                  'conversation_id': 'thread-1',
                  'sender_id': 'u2',
                  'sender_name': 'Vendor',
                  'sender_role': 'vendor',
                  'text': 'Second photo',
                  'timestamp': '2026-11-01T10:01:00Z',
                  'is_read': true,
                  'attachment_url': 'chat-attachments/thread-1/u2/b.jpg',
                  'attachment_type': 'image',
                },
              ]),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/storage/v1/object/sign/chat-attachments') {
            signCalls++;
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final paths = (body['paths'] as List).cast<String>();
            return http.Response(
              jsonEncode(
                paths
                    .map(
                      (p) => {
                        'path': p,
                        'signedURL': '/object/sign/chat-attachments/$p?token=tok-$signCalls',
                      },
                    )
                    .toList(),
              ),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            'Unexpected request: ${request.url.path}',
            500,
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);

      final repo = SupabaseMessagingRepository(client: client);
      final first = await repo.getMessages('thread-1');
      final second = await repo.getMessages('thread-1');

      expect(signCalls, 1);
      expect(
        first[0].attachmentUrl,
        'https://example.supabase.co/storage/v1/object/sign/chat-attachments/thread-1/u1/a.jpg?token=tok-1',
      );
      expect(
        first[1].attachmentUrl,
        'https://example.supabase.co/storage/v1/object/sign/chat-attachments/thread-1/u2/b.jpg?token=tok-1',
      );
      expect(second[0].attachmentUrl, first[0].attachmentUrl);
      expect(second[1].attachmentUrl, first[1].attachmentUrl);
    },
  );
}
