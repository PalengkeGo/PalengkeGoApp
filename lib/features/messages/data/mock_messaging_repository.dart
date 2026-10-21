import 'package:palengkego/features/messages/data/shared_messaging_store.dart';
import 'package:palengkego/features/messages/domain/chat_conversation.dart';
import 'package:palengkego/features/messages/domain/chat_message.dart';
import 'package:palengkego/features/messages/domain/messaging_repository.dart';

class MockMessagingRepository implements MessagingRepository {
  final SharedMessagingStore _store;

  MockMessagingRepository({SharedMessagingStore? store})
      : _store = store ?? SharedMessagingStore();

  @override
  Stream<List<ChatConversation>> watchConversationsForVendor(String stallId) {
    final normalizedStallId =
        (stallId == 'stall holder-001' || stallId == 'vendor-001')
            ? 'v1'
            : stallId;
    return _store.watchConversations().map((list) {
      return list
          .where((c) =>
              c.stallId == normalizedStallId ||
              c.stallId == stallId ||
              (normalizedStallId == 'v1' &&
                  (c.stallId == 'v1' ||
                      c.stallId == 'stall holder-001' ||
                      c.stallId == 'vendor-001')))
          .toList();
    });
  }

  @override
  Stream<List<ChatConversation>> watchConversationsForCustomer(
    String customerUid,
  ) {
    return _store.watchConversations().map((list) {
      return list.where((c) => c.customerUid == customerUid).toList();
    });
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _store.watchMessages(conversationId);
  }

  @override
  Future<List<ChatConversation>> getConversationsForVendor(
    String stallId,
  ) async {
    await _store.load();
    final normalizedStallId =
        (stallId == 'stall holder-001' || stallId == 'vendor-001')
            ? 'v1'
            : stallId;
    return _store.conversations
        .where((c) =>
            c.stallId == normalizedStallId ||
            c.stallId == stallId ||
            (normalizedStallId == 'v1' &&
                (c.stallId == 'v1' ||
                    c.stallId == 'stall holder-001' ||
                    c.stallId == 'vendor-001')))
        .toList();
  }

  @override
  Future<List<ChatConversation>> getConversationsForCustomer(
    String customerUid,
  ) async {
    await _store.load();
    return _store.conversations
        .where((c) => c.customerUid == customerUid)
        .toList();
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    await _store.load();
    return _store.getMessages(conversationId);
  }

  @override
  Future<ChatConversation> getOrCreateConversation({
    required String customerUid,
    required String customerName,
    required String stallId,
    required String stallName,
    String? stallAvatar,
    String? customerAvatar,
    String inquiryType = 'general',
    String? relatedOrderId,
  }) async {
    return _store.getOrCreateConversation(
      customerUid: customerUid,
      customerName: customerName,
      stallId: stallId,
      stallName: stallName,
      stallAvatar: stallAvatar,
      customerAvatar: customerAvatar,
      inquiryType: inquiryType,
      relatedOrderId: relatedOrderId,
    );
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    return _store.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      text: text,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
    );
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String readerRole,
  }) async {
    await _store.markAsRead(
      conversationId: conversationId,
      readerRole: readerRole,
    );
  }

  @override
  Stream<int> watchVendorUnreadCount(String stallId) {
    return watchConversationsForVendor(stallId).map((list) {
      return list.where((c) => c.vendorUnreadCount > 0).length;
    });
  }

  @override
  Stream<int> watchCustomerUnreadCount(String customerUid) {
    return watchConversationsForCustomer(customerUid).map((list) {
      return list.where((c) => c.customerUnreadCount > 0).length;
    });
  }
}
