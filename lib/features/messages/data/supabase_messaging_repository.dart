import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
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
    FirebaseAuth? auth,
    WebSocketMessagingService? wsService,
  })  : _client = client,
        _auth = auth,
        _wsService = wsService;

  final SupabaseClient _client;
  final FirebaseAuth? _auth;
  final WebSocketMessagingService? _wsService;

  FirebaseAuth? get auth => _auth;
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
  Stream<List<ChatConversation>> watchConversationsForCustomer(String customerUid) {
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
        .map((rows) => rows.map(_mapMessage).toList());
  }

  @override
  Future<List<ChatConversation>> getConversationsForVendor(String stallId) async {
    try {
      final response = await _client
          .from('conversations')
          .select()
          .eq('stall_id', stallId)
          .order('last_message_timestamp', ascending: false);

      final list = (response as List<dynamic>? ?? []);
      return list.map((r) => _mapConversation(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SupabaseMessaging] Error fetching vendor conversations: $e');
      }
      return [];
    }
  }

  @override
  Future<List<ChatConversation>> getConversationsForCustomer(String customerUid) async {
    try {
      final response = await _client
          .from('conversations')
          .select()
          .eq('customer_uid', customerUid)
          .order('last_message_timestamp', ascending: false);

      final list = (response as List<dynamic>? ?? []);
      return list.map((r) => _mapConversation(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SupabaseMessaging] Error fetching customer conversations: $e');
      }
      return [];
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
      return list.map((r) => _mapMessage(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SupabaseMessaging] Error fetching messages: $e');
      }
      return [];
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
    // 1. Check if conversation already exists
    try {
      final existing = await _client
          .from('conversations')
          .select()
          .eq('stall_id', stallId)
          .eq('customer_uid', customerUid)
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        return _mapConversation(Map<String, dynamic>.from(existing));
      }
    } catch (_) {}

    // 2. Insert new conversation thread
    final now = DateTime.now().toIso8601String();
    final row = {
      'stall_id': stallId,
      'stall_name': stallName,
      'stall_avatar': ?stallAvatar,
      'customer_uid': customerUid,
      'customer_name': customerName,
      'customer_avatar': ?customerAvatar,
      'last_message_text': '',
      'last_message_timestamp': now,
      'last_message_sender_id': customerUid,
      'customer_unread_count': 0,
      'vendor_unread_count': 0,
      'inquiry_type': inquiryType,
      'related_order_id': ?relatedOrderId,
      'created_at': now,
      'updated_at': now,
    };

    final inserted = await _client
        .from('conversations')
        .insert(row)
        .select()
        .single();

    return _mapConversation(Map<String, dynamic>.from(inserted));
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
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final previewText = (attachmentUrl != null && attachmentUrl.isNotEmpty && text.trim().isEmpty)
        ? '📷 Photo'
        : text.trim();

    // 1. Insert message
    final msgRow = {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'text': text.trim(),
      'timestamp': nowIso,
      'is_read': false,
      if (attachmentUrl != null && attachmentUrl.isNotEmpty) 'attachment_url': attachmentUrl,
      'attachment_type': ?attachmentType,
    };

    final inserted = await _client
        .from('messages')
        .insert(msgRow)
        .select()
        .single();

    final message = _mapMessage(Map<String, dynamic>.from(inserted));

    // 2. Fetch current unread count to increment
    try {
      final convData = await _client
          .from('conversations')
          .select('vendor_unread_count, customer_unread_count')
          .eq('id', conversationId)
          .maybeSingle();

      int currentVendorUnread = 0;
      int currentCustomerUnread = 0;
      if (convData != null) {
        currentVendorUnread = (convData['vendor_unread_count'] as int?) ?? 0;
        currentCustomerUnread = (convData['customer_unread_count'] as int?) ?? 0;
      }

      final isVendor = senderRole == 'vendor';
      await _client.from('conversations').update({
        'last_message_text': previewText,
        'last_message_timestamp': nowIso,
        'last_message_sender_id': senderId,
        'updated_at': nowIso,
        if (isVendor)
          'customer_unread_count': currentCustomerUnread + 1
        else
          'vendor_unread_count': currentVendorUnread + 1,
      }).eq('id', conversationId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SupabaseMessaging] Failed to update conversation summary: $e');
      }
    }

    return message;
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String readerRole,
  }) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      final senderRoleToMark = readerRole == 'vendor' ? 'customer' : 'vendor';

      // 1. Mark unread incoming messages as read
      await _client
          .from('messages')
          .update({'is_read': true, 'read_at': nowIso})
          .eq('conversation_id', conversationId)
          .eq('sender_role', senderRoleToMark)
          .eq('is_read', false);

      // 2. Reset reader unread count to zero on conversation
      final updateField = readerRole == 'vendor'
          ? {'vendor_unread_count': 0}
          : {'customer_unread_count': 0};

      await _client
          .from('conversations')
          .update(updateField)
          .eq('id', conversationId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SupabaseMessaging] Error marking as read: $e');
      }
    }
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
