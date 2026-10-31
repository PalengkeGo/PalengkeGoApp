import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/support_chat_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth extends Fake implements FirebaseAuth {}

class _Api extends SupportChatClient {
  _Api()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        _Auth(),
        url: 'https://example.supabase.co',
        anonKey: 'test',
      );
  final records = <Map<String, dynamic>>[];
  int requests = 0;
  Completer<void>? gate;
  @override
  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    requests++;
    await gate?.future;
    int compare(Map a, Map b) {
      final date = a['created_at'].toString().compareTo(
        b['created_at'].toString(),
      );
      return date == 0
          ? a['id'].toString().compareTo(b['id'].toString())
          : date;
    }

    final before = data['before'] as Map?;
    final after = data['after'] as Map?;
    final rows = records.where((row) {
      if (before != null &&
          compare(row, {'created_at': before['at'], 'id': before['id']}) >= 0) {
        return false;
      }
      if (after != null &&
          compare(row, {'created_at': after['at'], 'id': after['id']}) <= 0) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => after != null ? compare(a, b) : -compare(a, b));
    final page = rows.take(50).toList();
    final next = rows.length > 50
        ? {'at': page.last['created_at'], 'id': page.last['id']}
        : null;
    return {
      'messages': after != null ? page : page.reversed.toList(),
      'nextCursor': next,
    };
  }

  void add(int start, int end) {
    for (var i = start; i <= end; i++) {
      records.add({
        'id': i.toString().padLeft(4, '0'),
        'created_at': '2026-10-30T00:00:00.123456Z',
        'body': 'Message $i',
      });
    }
  }
}

void main() {
  test(
    'older pages preserve chronological messages with identical timestamps',
    () async {
      final api = _Api()..add(1, 120);
      addTearDown(api.dispose);
      expect((await api.load('thread')).length, 50);
      expect(api.hasOlder('thread'), isTrue);
      await api.loadOlder('thread');
      await api.loadOlder('thread');
      final rows = await api.load('thread');
      expect(rows.length, 120);
      expect(rows.first['id'], '0001');
      expect(rows.last['id'], '0120');
      expect(api.hasOlder('thread'), isFalse);
    },
  );
  test(
    'reconnect catches up more than 50 missed replies without duplicates',
    () async {
      final api = _Api()..add(1, 1);
      addTearDown(api.dispose);
      await api.load('thread');
      api.add(2, 121);
      final rows = await api.load('thread');
      expect(rows.length, 121);
      expect(rows.map((row) => row['id']).toSet().length, 121);
      expect(rows.last['id'], '0121');
    },
  );
  test('concurrent loads share one in-flight request', () async {
    final api = _Api()..add(1, 5);
    addTearDown(api.dispose);
    api.gate = Completer<void>();
    final first = api.load('thread');
    final second = api.load('thread');
    expect(api.requests, 1);
    api.gate!.complete();
    expect(await first, await second);
  });
  test(
    'unsupported or oversized photos are rejected before requesting upload credentials',
    () async {
      final api = _Api();
      addTearDown(api.dispose);
      await expectLater(
        api.upload('thread', 'data:text/html;base64,SGk='),
        throwsStateError,
      );
      await expectLater(
        api.upload(
          'thread',
          'data:image/png;base64,${base64Encode(List.filled(2097153, 0))}',
        ),
        throwsStateError,
      );
      expect(api.requests, 0);
    },
  );
}
