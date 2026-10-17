import 'package:palengkego/features/messages/domain/chat_conversation.dart';
import 'package:palengkego/features/messages/domain/chat_message.dart';

abstract class MessagingRepository {
  Stream<List<ChatConversation>> watchConversationsForVendor(String stallId);
  Stream<List<ChatConversation>> watchConversationsForCustomer(String customerUid);
  Stream<List<ChatMessage>> watchMessages(String conversationId);

  Future<List<ChatConversation>> getConversationsForVendor(String stallId);
  Future<List<ChatConversation>> getConversationsForCustomer(String customerUid);
  Future<List<ChatMessage>> getMessages(String conversationId);

  Future<ChatConversation> getOrCreateConversation({
    required String customerUid,
    required String customerName,
    required String stallId,
    required String stallName,
    String? stallAvatar,
    String? customerAvatar,
    String inquiryType = 'general',
    String? relatedOrderId,
  });

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
    String? attachmentUrl,
    String? attachmentType,
  });

  Future<void> markAsRead({
    required String conversationId,
    required String readerRole, // 'vendor' | 'customer'
  });

  Stream<int> watchVendorUnreadCount(String stallId);
  Stream<int> watchCustomerUnreadCount(String customerUid);
}
