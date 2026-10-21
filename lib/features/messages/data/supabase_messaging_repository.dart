import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:palengkego/features/messages/data/websocket_messaging_service.dart';
import 'package:palengkego/features/messages/domain/chat_conversation.dart';
import 'package:palengkego/features/messages/domain/chat_message.dart';
import 'package:palengkego/features/messages/domain/messaging_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [MessagingRepository] with real-time WebSocket support.
///
/// Features:
/// - Real-time stream listening via Supabase Postgres CDC over WebSockets
/// - Ephemeral typing indicators via [WebSocketMessagingService]
/// - Zero custom server maintenance with row-level security
class SupabaseMessagingRepository implements MessagingRepository {
  SupabaseMessagingRepository({
    required SupabaseClient client,
    WebSocketMessagingService? wsService,
  }) : _client = client,
       _wsService = wsService;

  final SupabaseClient _client;
  final WebSocketMessagingService? _wsService;

  WebSocketMessagingService? get wsService => _wsService;

  @override
  Stream<List<ChatConversation>> watchConversationsForVendor(String stallId) {
    return _client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('stall_id', stallId)
        .order('last_message_timestamp', ascending: false)
        .map((rows) => rows.map(_mapConversation).toList());
  }

  @override
  Stream<List<ChatConversation>> watchConversationsForCustomer(
    String customerUid,
  ) {
    return _client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('customer_uid', customerUid)
        .order('last_message_timestamp', ascending: false)
        .map((rows) => rows.map(_mapConversation).toList());
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    // Ensure WebSocket channel is active for this conversation room
    _wsService?.subscribeToConversation(conversationId: conversationId);

    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('timestamp', ascending: true)
        .asyncMap((rows) => Future.wait(rows.map(_readMessage)));
  }

  @override
  Future<List<ChatConversation>> getConversationsForVendor(
    String stallId,
  ) async {
    try {
      final response = await _client
          .from('conversations')
          .select()
          .eq('stall_id', stallId)
          .order('last_message_timestamp', ascending: false);

      final list = (response as List<dynamic>? ?? []);
      return list
          .map((r) => _mapConversation(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[SupabaseMessaging] Error fetching vendor conversations: $e',
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<ChatConversation>> getConversationsForCustomer(
    String customerUid,
  ) async {
    try {
      final response = await _client
          .from('conversations')
          .select()
          .eq('customer_uid', customerUid)
          .order('last_message_timestamp', ascending: false);

      final list = (response as List<dynamic>? ?? []);
      return list
          .map((r) => _mapConversation(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[SupabaseMessaging] Error fetching customer conversations: $e',
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('timestamp', ascending: true);

      final list = (response as List<dynamic>? ?? []);
      return await Future.wait(
        list.map((r) => _readMessage(Map<String, dynamic>.from(r as Map))),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SupabaseMessaging] Error fetching messages: $e');
      }
      rethrow;
    }
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
    final row = await _client
        .rpc(
          'chat_get_or_create',
          params: {
            'p_stall_id': stallId,
            'p_customer_uid': customerUid,
            'p_inquiry_type': inquiryType,
            'p_related_order_id': relatedOrderId,
          },
        )
        .single();
    return _mapConversation(Map<String, dynamic>.from(row));
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
    // Identity, timestamps, summary and unread counts are database-owned.
    final row = await _client
        .rpc(
          'chat_send_message',
          params: {
            'p_conversation_id': conversationId,
            'p_text': text,
            'p_attachment_url': attachmentUrl,
            'p_attachment_type': attachmentType,
          },
        )
        .single();
    return _mapMessage(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String readerRole,
  }) async {
    await _client.rpc(
      'chat_mark_read',
      params: {'p_conversation_id': conversationId},
    );
  }

  @override
  Stream<int> watchVendorUnreadCount(String stallId) {
    return watchConversationsForVendor(stallId).map((conversations) {
      return conversations.where((c) => c.vendorUnreadCount > 0).length;
    });
  }

  @override
  Stream<int> watchCustomerUnreadCount(String customerUid) {
    return watchConversationsForCustomer(customerUid).map((conversations) {
      return conversations.where((c) => c.customerUnreadCount > 0).length;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Row Mapping Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  ChatConversation _mapConversation(Map<String, dynamic> row) {
    final now = DateTime.now();
    return ChatConversation(
      id: row['id']?.toString() ?? '',
      stallId: row['stall_id']?.toString() ?? '',
      stallName: row['stall_name']?.toString() ?? '',
      stallAvatar: row['stall_avatar']?.toString(),
      customerUid: row['customer_uid']?.toString() ?? '',
      customerName: row['customer_name']?.toString() ?? '',
      customerAvatar: row['customer_avatar']?.toString(),
      lastMessageText: row['last_message_text']?.toString() ?? '',
      lastMessageTimestamp: row['last_message_timestamp'] != null
          ? DateTime.tryParse(row['last_message_timestamp'].toString()) ?? now
          : now,
      lastMessageSenderId: row['last_message_sender_id']?.toString() ?? '',
      customerUnreadCount: (row['customer_unread_count'] as int?) ?? 0,
      vendorUnreadCount: (row['vendor_unread_count'] as int?) ?? 0,
      inquiryType: row['inquiry_type']?.toString() ?? 'general',
      relatedOrderId: row['related_order_id']?.toString(),
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'].toString()) ?? now
          : now,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'].toString()) ?? now
          : now,
    );
  }

  Future<ChatMessage> _readMessage(Map<String, dynamic> row) async {
    final attachment = row['attachment_url']?.toString();
    if (attachment != null && attachment.startsWith('chat-attachments/')) {
      row = {
        ...row,
        'attachment_url': await _client.storage
            .from('chat-attachments')
            .createSignedUrl(
              attachment.substring('chat-attachments/'.length),
              3600,
            ),
      };
    }
    return _mapMessage(row);
  }

  ChatMessage _mapMessage(Map<String, dynamic> row) {
    final now = DateTime.now();
    return ChatMessage(
      id: row['id']?.toString() ?? '',
      conversationId: row['conversation_id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      senderName: row['sender_name']?.toString() ?? '',
      senderRole: row['sender_role']?.toString() ?? 'customer',
      text: row['text']?.toString() ?? '',
      timestamp: row['timestamp'] != null
          ? DateTime.tryParse(row['timestamp'].toString()) ?? now
          : now,
      isRead: row['is_read'] == true,
      readAt: row['read_at'] != null
          ? DateTime.tryParse(row['read_at'].toString())
          : null,
      attachmentUrl: row['attachment_url']?.toString(),
      attachmentType: row['attachment_type']?.toString(),
    );
  }
}
