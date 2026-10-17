import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:palengkego/features/messages/data/mock_messaging_repository.dart';
import 'package:palengkego/features/messages/data/shared_messaging_store.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('MessagingRepository & SharedMessagingStore Tests', () {
    test('initializes default conversations with reference counts', () async {
      final store = SharedMessagingStore();
      final repo = MockMessagingRepository(store: store);

      final conversations = await repo.getConversationsForVendor('v1');
      expect(conversations.length, 12);

      final unread = conversations.where((c) => c.vendorUnreadCount > 0).toList();
      expect(unread.length, 2);

      final orders = conversations.where((c) => c.inquiryType == 'order').toList();
      expect(orders.length, 5);

      expect(conversations.first.customerName, 'Ana Santos');
      expect(conversations.first.vendorUnreadCount, 2);
    });

    test('getMessages returns messages in chronological order', () async {
      final store = SharedMessagingStore();
      final repo = MockMessagingRepository(store: store);

      final messages = await repo.getMessages('conv_ana_santos');
      expect(messages.length, 4);
      expect(messages[0].text, contains('Good morning po'));
      expect(messages[3].text, contains('Available pa po ba ang lakatan bananas'));
      expect(messages[3].isRead, false);
    });

    test('sendMessage creates persistent message and increments unread count', () async {
      final store = SharedMessagingStore();
      final repo = MockMessagingRepository(store: store);

      final message = await repo.sendMessage(
        conversationId: 'conv_ana_santos',
        senderId: 'v1',
        senderName: "Mer's Mayao Fruit Stand",
        senderRole: 'vendor',
        text: 'Yes maam, available po! P80 per kilo.',
      );

      expect(message.id, isNotEmpty);
      expect(message.text, 'Yes maam, available po! P80 per kilo.');
      expect(message.senderRole, 'vendor');

      final updatedMessages = await repo.getMessages('conv_ana_santos');
      expect(updatedMessages.length, 5);
      expect(updatedMessages.last.text, 'Yes maam, available po! P80 per kilo.');

      final conversations = await repo.getConversationsForVendor('v1');
      final anaConv = conversations.firstWhere((c) => c.id == 'conv_ana_santos');
      expect(anaConv.lastMessageText, 'Yes maam, available po! P80 per kilo.');
      expect(anaConv.customerUnreadCount, 1);
    });

    test('markAsRead zeroes vendor unread count and marks messages as read', () async {
      final store = SharedMessagingStore();
      final repo = MockMessagingRepository(store: store);

      await repo.markAsRead(
        conversationId: 'conv_ana_santos',
        readerRole: 'vendor',
      );

      final conversations = await repo.getConversationsForVendor('v1');
      final anaConv = conversations.firstWhere((c) => c.id == 'conv_ana_santos');
      expect(anaConv.vendorUnreadCount, 0);

      final messages = await repo.getMessages('conv_ana_santos');
      final unreadCustomerMsgs =
          messages.where((m) => m.senderRole == 'customer' && !m.isRead);
      expect(unreadCustomerMsgs, isEmpty);
    });

    test('getOrCreateConversation avoids duplicate conversations', () async {
      final store = SharedMessagingStore();
      final repo = MockMessagingRepository(store: store);

      // Existing conversation
      final existing = await repo.getOrCreateConversation(
        customerUid: 'cust_ana_santos',
        customerName: 'Ana Santos',
        stallId: 'v1',
        stallName: "Mer's Mayao Fruit Stand",
      );
      expect(existing.id, 'conv_ana_santos');

      // New conversation for new customer
      final newConv = await repo.getOrCreateConversation(
        customerUid: 'cust_new_user_123',
        customerName: 'New Customer',
        stallId: 'v1',
        stallName: "Mer's Mayao Fruit Stand",
      );
      expect(newConv.id, 'conv_cust_new_user_123_v1');

      // Calling again returns the same conversation without duplicating
      final sameConv = await repo.getOrCreateConversation(
        customerUid: 'cust_new_user_123',
        customerName: 'New Customer',
        stallId: 'v1',
        stallName: "Mer's Mayao Fruit Stand",
      );
      expect(sameConv.id, newConv.id);
    });

    test('sendMessage with photo attachment sets attachmentUrl and preview', () async {
      final store = SharedMessagingStore();
      final repo = MockMessagingRepository(store: store);

      const fakeDataUri = 'data:image/jpeg;base64,/9j/4AAQSkZJRg==';
      final message = await repo.sendMessage(
        conversationId: 'conv_ana_santos',
        senderId: 'cust_ana_santos',
        senderName: 'Ana Santos',
        senderRole: 'customer',
        text: 'Eto po ba yung itsura?',
        attachmentUrl: fakeDataUri,
        attachmentType: 'image',
      );

      expect(message.hasAttachment, true);
      expect(message.isImageAttachment, true);
      expect(message.attachmentUrl, fakeDataUri);
      expect(message.attachmentType, 'image');

      final convs = await repo.getConversationsForVendor('v1');
      final anaConv = convs.firstWhere((c) => c.id == 'conv_ana_santos');
      expect(anaConv.lastMessageText, 'Eto po ba yung itsura?');
    });

    test('sendMessage with photo only (no text) sets preview to 📷 Photo', () async {
      final store = SharedMessagingStore();
      final repo = MockMessagingRepository(store: store);

      const fakeDataUri = 'data:image/jpeg;base64,/9j/4AAQSkZJRg==';
      final message = await repo.sendMessage(
        conversationId: 'conv_ana_santos',
        senderId: 'cust_ana_santos',
        senderName: 'Ana Santos',
        senderRole: 'customer',
        text: '',
        attachmentUrl: fakeDataUri,
      );

      expect(message.hasAttachment, true);
      expect(message.text, isEmpty);

      final convs = await repo.getConversationsForVendor('v1');
      final anaConv = convs.firstWhere((c) => c.id == 'conv_ana_santos');
      expect(anaConv.lastMessageText, '📷 Photo');
    });
  });
}
