import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/support_chat_client.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/messages/presentation/pages/admin_support_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth extends Fake implements FirebaseAuth {}

class _VendorAuth extends AuthNotifier {
  @override
  AppUser? build() => const AppUser(
    uid: 'vendor-1',
    email: 'vendor@example.com',
    role: UserRole.vendor,
  );
}

class _Support extends SupportChatClient {
  _Support()
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
  bool fail = true;
  String body = '';
  @override
  Stream<List<Map<String, dynamic>>> watch(String key) async* {
    yield key == 'conversations'
        ? []
        : [
            {
              'id': 'message-1',
              'sender_user_id': 'vendor-1',
              'sender_role': 'vendor',
              'body': body,
              'created_at': '2026-10-30T00:00:00Z',
              'read_at': null,
            },
          ];
  }

  @override
  bool hasOlder(String key) => false;
  @override
  void refresh(String key) {}
  @override
  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (fail) {
      throw StateError('Could not start the conversation.');
    }
    body = data['message'].toString();
    return {
      'conversation': {'id': '12345678-1234-4234-8234-123456789012'},
    };
  }
}

void main() {
  testWidgets(
    'stallholder start failure preserves draft and retry opens the live thread',
    (tester) async {
      final api = _Support();
      addTearDown(api.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_VendorAuth.new),
            supportChatProvider.overrideWith((ref) => api),
          ],
          child: const MaterialApp(home: AdminSupportScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Start a conversation using the message box below.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextField),
        'Help with my stall permit',
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Help with my stall permit'), findsOneWidget);
      expect(
        find.textContaining('Could not start the conversation.'),
        findsOneWidget,
      );
      api.fail = false;
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Help with my stall permit'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        find.text('Start a conversation using the message box below.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
