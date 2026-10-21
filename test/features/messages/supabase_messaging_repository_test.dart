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
}
