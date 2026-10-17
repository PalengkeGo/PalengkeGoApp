import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/messages/data/shared_messaging_store.dart';
import 'package:palengkego/features/messages/presentation/pages/chat_screen.dart';
import 'package:palengkego/features/messages/presentation/pages/messages_inbox_screen.dart';
import 'package:palengkego/features/messages/presentation/widgets/conversation_card.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_bottom_nav.dart';
import 'package:palengkego/features/messages/domain/chat_message.dart';
import 'package:palengkego/features/messages/presentation/widgets/chat_bubble.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_account_screen.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_profile_screen.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform {}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.initialUser);
  final AppUser? initialUser;
  @override
  AppUser? build() => initialUser;
}

void main() {
  late SharedPreferences prefs;
  late SharedMessagingStore messagingStore;

  setUp(() async {
    FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    messagingStore = SharedMessagingStore();
    await messagingStore.load();
  });

  Widget wrap(Widget child, {AppUser? user}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => _TestAuthNotifier(user ?? MockUsers.vendor)),
        sharedMessagingStoreProvider.overrideWithValue(messagingStore),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  group('VendorDashboardBottomNav', () {
    testWidgets('renders all 5 tabs including Messages with badge', (tester) async {
      int selected = 0;
      await tester.pumpWidget(
        wrap(
          VendorDashboardBottomNav(
            selectedIndex: selected,
            onSelect: (index) => selected = index,
            unreadCount: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // badge count
    });
  });

  group('MessagesInboxScreen', () {
    testWidgets('displays header, search bar, filter chips and conversation cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const MessagesInboxScreen(isEmbeddedInTab: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Search messages, customers, or orders...'), findsOneWidget);
      expect(find.text('All (12)'), findsOneWidget);
      expect(find.text('Unread (2)'), findsOneWidget);
      expect(find.text('Orders (5)'), findsOneWidget);
      expect(find.byType(ConversationCard), findsWidgets);
      expect(find.text('Ana Santos'), findsOneWidget);
      expect(find.text('Mark Dela Cruz'), findsOneWidget);
    });

    testWidgets('filtering by Unread displays only unread conversations', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const MessagesInboxScreen(isEmbeddedInTab: true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unread (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Ana Santos'), findsOneWidget);
      expect(find.text('Mark Dela Cruz'), findsOneWidget);
      expect(find.text('Liza Reyes'), findsNothing);
    });

    testWidgets('search filters conversations by name', (tester) async {
      await tester.pumpWidget(
        wrap(const MessagesInboxScreen(isEmbeddedInTab: true)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.pumpAndSettle();

      expect(find.text('Ana Santos'), findsOneWidget);
      expect(find.text('Mark Dela Cruz'), findsNothing);
    });
  });

  group('ChatScreen', () {
    testWidgets('renders chat messages, header and composer', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ChatScreen(
            conversationId: 'conv_ana_santos',
            displayName: 'Ana Santos',
            isVendorView: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana Santos'), findsOneWidget);
      expect(find.text('Type a message...'), findsOneWidget);
      expect(find.textContaining('Available pa po ba'), findsOneWidget);
    });

    testWidgets('sending message adds it to conversation', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ChatScreen(
            conversationId: 'conv_ana_santos',
            displayName: 'Ana Santos',
            isVendorView: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Bagong bagsak po kanina!');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Bagong bagsak po kanina!'), findsOneWidget);
    });

    testWidgets('tapping attachment button opens source sheet with camera and gallery', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ChatScreen(
            conversationId: 'conv_ana_santos',
            displayName: 'Ana Santos',
            isVendorView: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final attachButton = find.byKey(const Key('chat_attachment_button'));
      expect(attachButton, findsOneWidget);

      await tester.tap(attachButton);
      await tester.pumpAndSettle();

      expect(find.text('Attach Photo'), findsOneWidget);
      expect(find.text('Take Photo (Camera)'), findsOneWidget);
      expect(find.text('Choose from Gallery (Photos)'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Close bottom sheet
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Attach Photo'), findsNothing);
    });

    testWidgets('ChatBubble renders message with photo attachment', (tester) async {
      const fakeDataUri = 'data:image/jpeg;base64,/9j/4AAQSkZJRg==';
      final photoMessage = ChatMessage(
        id: 'msg_photo_test',
        conversationId: 'conv_ana_santos',
        senderId: 'cust_ana_santos',
        senderName: 'Ana Santos',
        senderRole: 'customer',
        text: 'Eto po ba yung available?',
        timestamp: DateTime.now(),
        attachmentUrl: fakeDataUri,
        attachmentType: 'image',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: photoMessage,
              isOutgoing: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Eto po ba yung available?'), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in_rounded), findsOneWidget);
    });
  });

  group('VendorAccountScreen (Profile)', () {
    testWidgets('displays Customer Messages card with unread badge', (tester) async {
      await tester.pumpWidget(wrap(const VendorAccountScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Customer Messages'), findsOneWidget);
      expect(
        find.text('Reply to customer inquiries and order concerns'),
        findsOneWidget,
      );
      expect(find.text('2'), findsWidgets); // unread badge count
    });
  });

  group('Customer Stall Detail Screen', () {
    testWidgets('displays Chat with Stall Holder button', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VendorProfileScreen(vendorId: 'v1'),
          user: MockUsers.customer,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Chat with Stall Holder'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
