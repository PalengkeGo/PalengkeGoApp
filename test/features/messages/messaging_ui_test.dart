import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/messages/data/shared_messaging_store.dart';
import 'package:palengkego/features/messages/application/messaging_provider.dart';
import 'package:palengkego/features/messages/presentation/pages/chat_screen.dart';
import 'package:palengkego/features/messages/presentation/pages/messages_inbox_screen.dart';
import 'package:palengkego/features/messages/presentation/widgets/conversation_card.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_bottom_nav.dart';
import 'package:palengkego/features/messages/domain/chat_message.dart';
import 'package:palengkego/features/messages/presentation/widgets/chat_bubble.dart';
import 'package:palengkego/features/home/presentation/widgets/home_header.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_account_screen.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_profile_screen.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/features/vendors/presentation/widgets/vendor_order_header_card.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';

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
        authProvider.overrideWith(
          () => _TestAuthNotifier(user ?? MockUsers.vendor),
        ),
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
    testWidgets('order customer name opens vendor conversation', (
      tester,
    ) async {
      final order = MarketOrder(
        id: 'order-chat',
        customerUid: 'customer-chat',
        customerName: 'Chat Customer',
        stallId: 'stall-chat',
        vendorName: 'Stall',
        vendorImage: '',
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
        fulfillmentMethod: FulfillmentMethod.delivery,
        placedAt: DateTime.now(),
        items: [],
        deliveryFee: 30,
        serviceFee: 0,
      );
      await tester.pumpWidget(
        wrap(Scaffold(body: VendorOrderHeaderCard(order: order))),
      );
      await tester.tap(find.text('Chat Customer'));
      await tester.pumpAndSettle();
      final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
      expect(chat.isVendorView, isTrue);
      expect(chat.stallId, 'stall-chat');
      expect(chat.relatedOrderId, 'order-chat');
      expect(
        messagingStore.conversations
            .singleWhere((c) => c.id == chat.conversationId)
            .customerUid,
        'customer-chat',
      );
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('renders all 5 tabs including Messages with badge', (
      tester,
    ) async {
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
    for (final isVendor in [false, true]) {
      testWidgets('empty inbox shows no messages for vendor=$isVendor', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            ProviderScope(
              overrides: [
                customerConversationsProvider.overrideWith(
                  (ref) => Stream.value([]),
                ),
                vendorConversationsProvider.overrideWith(
                  (ref) => Stream.value([]),
                ),
              ],
              child: MessagesInboxScreen(isVendorView: isVendor),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('No messages yet'), findsOneWidget);
        expect(find.byType(ConversationCard), findsNothing);
        expect(find.text('Retry'), findsNothing);
      });
    }

    testWidgets('load errors show Retry instead of a false empty inbox', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ProviderScope(
            overrides: [
              customerConversationsProvider.overrideWith(
                (ref) => Stream.error(StateError('backend unavailable')),
              ),
            ],
            child: const MessagesInboxScreen(isVendorView: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to load messages. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No messages yet'), findsNothing);
    });

    testWidgets('empty conversation shows no messages yet', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProviderScope(
            overrides: [
              conversationMessagesProvider(
                'empty',
              ).overrideWith((ref) => Stream.value([])),
            ],
            child: const ChatScreen(
              conversationId: 'empty',
              displayName: 'Stall',
              isVendorView: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No messages yet'), findsOneWidget);
    });

    testWidgets(
      'displays header, search bar, filter chips and conversation cards',
      (tester) async {
        await tester.pumpWidget(
          wrap(const MessagesInboxScreen(isEmbeddedInTab: true)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Messages'), findsOneWidget);
        expect(
          find.text('Search messages, customers, or orders...'),
          findsOneWidget,
        );
        expect(find.text('All (12)'), findsOneWidget);
        expect(find.text('Unread (2)'), findsOneWidget);
        expect(find.text('Orders (5)'), findsOneWidget);
        expect(find.byType(ConversationCard), findsWidgets);
        expect(find.text('Ana Santos'), findsOneWidget);
        expect(find.text('Mark Dela Cruz'), findsOneWidget);
      },
    );

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

    testWidgets('customer view displays stall holder conversation history', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const MessagesInboxScreen(
            isEmbeddedInTab: false,
            isVendorView: false,
          ),
          user: MockUsers.customer,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Messages'), findsOneWidget);
      expect(
        find.text('Search messages, stalls, or orders...'),
        findsOneWidget,
      );
      expect(find.text("Aling Nena's Fresh Gulay"), findsOneWidget);
      expect(find.text("Pedro's Fresh Catch"), findsOneWidget);
      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('Unread (1)'), findsOneWidget);
    });
  });

  group('Customer HomeHeader Messages Icon', () {
    testWidgets(
      'places Messages icon to the left of Notification Bell and navigates to customer inbox',
      (tester) async {
        await tester.pumpWidget(
          wrap(const Scaffold(body: HomeHeader()), user: MockUsers.customer),
        );
        await tester.pumpAndSettle();

        final messagesButton = find.byKey(
          const Key('home_header_messages_button'),
        );
        final notificationsButton = find.byKey(
          const Key('home_header_notifications_button'),
        );

        expect(messagesButton, findsOneWidget);
        expect(notificationsButton, findsOneWidget);

        // Verify Messages icon is positioned directly to the left of Notification Bell
        final messagesCenter = tester.getCenter(messagesButton);
        final notificationsCenter = tester.getCenter(notificationsButton);
        expect(messagesCenter.dx, lessThan(notificationsCenter.dx));

        // Tapping Messages icon opens the Customer Messages History inbox
        await tester.tap(messagesButton);
        await tester.pumpAndSettle();

        expect(find.text("Aling Nena's Fresh Gulay"), findsOneWidget);
        expect(find.text("Pedro's Fresh Catch"), findsOneWidget);
      },
    );
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

      await tester.enterText(
        find.byType(TextField),
        'Bagong bagsak po kanina!',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Bagong bagsak po kanina!'), findsOneWidget);
    });

    testWidgets(
      'tapping attachment button opens source sheet with camera and gallery',
      (tester) async {
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
      },
    );

    testWidgets('ChatBubble renders message with photo attachment', (
      tester,
    ) async {
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
            body: ChatBubble(message: photoMessage, isOutgoing: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Eto po ba yung available?'), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in_rounded), findsOneWidget);
    });
  });

  group('VendorAccountScreen (Profile)', () {
    testWidgets('displays Customer Messages card with unread badge', (
      tester,
    ) async {
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
