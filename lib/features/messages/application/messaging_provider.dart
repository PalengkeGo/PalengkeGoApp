import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/messages/data/mock_messaging_repository.dart';
import 'package:palengkego/features/messages/data/shared_messaging_store.dart';
import 'package:palengkego/features/messages/domain/chat_conversation.dart';
import 'package:palengkego/features/messages/domain/chat_message.dart';
import 'package:palengkego/features/messages/domain/messaging_repository.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final store = ref.watch(sharedMessagingStoreProvider);
  return MockMessagingRepository(store: store);
});

/// Stream of conversations for the currently logged in vendor stall.
final vendorConversationsProvider =
    StreamProvider.autoDispose<List<ChatConversation>>((ref) async* {
  final repo = ref.watch(messagingRepositoryProvider);
  final stall = ref.watch(vendorStallProvider);
  final currentVendorId = ref.watch(currentVendorIdProvider);
  final stallId = currentVendorId ?? stall.stallId;

  final initial = await repo.getConversationsForVendor(stallId);
  yield initial;

  yield* repo.watchConversationsForVendor(stallId);
});

/// Stream of conversations for the customer.
final customerConversationsProvider =
    StreamProvider.autoDispose<List<ChatConversation>>((ref) async* {
  final repo = ref.watch(messagingRepositoryProvider);
  final user = ref.watch(authProvider);
  final customerUid = user?.uid ?? 'customer-001';

  final initial = await repo.getConversationsForCustomer(customerUid);
  yield initial;

  yield* repo.watchConversationsForCustomer(customerUid);
});

/// Stream of messages for a single conversation.
final conversationMessagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((
  ref,
  conversationId,
) async* {
  final repo = ref.watch(messagingRepositoryProvider);

  final initial = await repo.getMessages(conversationId);
  yield initial;

  yield* repo.watchMessages(conversationId);
});

/// Total unread conversation count for vendor (used on badges).
final vendorUnreadMessagesCountProvider = Provider<int>((ref) {
  final conversationsAsync = ref.watch(vendorConversationsProvider);
  return conversationsAsync.maybeWhen(
    data: (conversations) {
      return conversations.where((c) => c.vendorUnreadCount > 0).length;
    },
    orElse: () => 0,
  );
});

/// Total unread conversation count for customer.
final customerUnreadMessagesCountProvider = Provider<int>((ref) {
  final conversationsAsync = ref.watch(customerConversationsProvider);
  return conversationsAsync.maybeWhen(
    data: (conversations) {
      return conversations.where((c) => c.customerUnreadCount > 0).length;
    },
    orElse: () => 0,
  );
});

/// Provider for messaging actions (send, mark read, getOrCreate).
final messagingActionsProvider = Provider<MessagingActions>((ref) {
  final repo = ref.watch(messagingRepositoryProvider);
  return MessagingActions(repo);
});

class MessagingActions {
  final MessagingRepository _repo;
  MessagingActions(this._repo);

  Future<ChatConversation> getOrCreateConversation({
    required String customerUid,
    required String customerName,
    required String stallId,
    required String stallName,
    String? stallAvatar,
    String? customerAvatar,
    String inquiryType = 'general',
    String? relatedOrderId,
  }) {
    return _repo.getOrCreateConversation(
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

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
    String? attachmentUrl,
    String? attachmentType,
  }) {
    return _repo.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      text: text,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
    );
  }

  Future<void> markAsRead({
    required String conversationId,
    required String readerRole,
  }) {
    return _repo.markAsRead(
      conversationId: conversationId,
      readerRole: readerRole,
    );
  }
}
