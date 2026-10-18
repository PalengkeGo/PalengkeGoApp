import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages real-time WebSocket communication for in-app chat.
///
/// Uses Supabase Realtime Channels operating over persistent WebSockets (WSS).
/// Supports:
/// - Instant message pushes via Postgres CDC over WebSocket
/// - Ephemeral typing indicators (`typing`) via WebSocket Broadcast
/// - Connection lifecycle and channel cleanup
class WebSocketMessagingService {
  WebSocketMessagingService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  final Map<String, RealtimeChannel> _activeChannels = {};
  final Map<String, StreamController<bool>> _typingControllers = {};
  final Map<String, Timer> _typingTimers = {};

  bool get isAvailable => _client != null;

  /// Subscribes to a conversation's WebSocket channel.
  RealtimeChannel? subscribeToConversation({
    required String conversationId,
    void Function(Map<String, dynamic> record)? onNewMessage,
    void Function(Map<String, dynamic> record)? onMessageUpdated,
  }) {
    final client = _client;
    if (client == null) return null;

    // Return existing channel if already subscribed
    if (_activeChannels.containsKey(conversationId)) {
      return _activeChannels[conversationId];
    }

    final channelName = 'chat-room-$conversationId';
    final channel = client.channel(channelName);

    // 1. WebSocket Broadcast: Typing indicators
    channel.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final senderId = payload['sender_id']?.toString() ?? '';
        final isTyping = payload['is_typing'] == true;
        _handleTypingReceived(conversationId, senderId, isTyping);
      },
    );

    // 2. WebSocket Postgres Changes: Insert (new message)
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) {
        if (onNewMessage != null && payload.newRecord.isNotEmpty) {
          onNewMessage(payload.newRecord);
        }
      },
    );

    // 3. WebSocket Postgres Changes: Update (read receipts)
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) {
        if (onMessageUpdated != null && payload.newRecord.isNotEmpty) {
          onMessageUpdated(payload.newRecord);
        }
      },
    );

    channel.subscribe((status, error) {
      if (kDebugMode) {
        debugPrint('[WebSocket] Channel $channelName status: $status (error: $error)');
      }
    });

    _activeChannels[conversationId] = channel;
    return channel;
  }

  /// Broadcasts a typing status over the WebSocket connection.
  Future<void> sendTyping({
    required String conversationId,
    required String senderId,
    required bool isTyping,
  }) async {
    final channel = _activeChannels[conversationId];
    if (channel == null) return;

    try {
      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'sender_id': senderId,
          'is_typing': isTyping,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebSocket] Failed to send typing broadcast: $e');
      }
    }
  }

  /// Returns a stream of typing state for the counterpart in [conversationId].
  Stream<bool> watchTyping(String conversationId, String currentUserId) {
    _typingControllers[conversationId] ??= StreamController<bool>.broadcast();
    return _typingControllers[conversationId]!.stream;
  }

  void _handleTypingReceived(
    String conversationId,
    String senderId,
    bool isTyping,
  ) {
    final controller = _typingControllers[conversationId];
    if (controller == null || controller.isClosed) return;

    if (isTyping) {
      controller.add(true);
      _typingTimers[conversationId]?.cancel();
      // Auto-clear typing indicator after 3 seconds of inactivity
      _typingTimers[conversationId] = Timer(const Duration(seconds: 3), () {
        if (!controller.isClosed) {
          controller.add(false);
        }
      });
    } else {
      _typingTimers[conversationId]?.cancel();
      controller.add(false);
    }
  }

  /// Unsubscribes and cleans up the WebSocket channel for [conversationId].
  void unsubscribe(String conversationId) {
    final channel = _activeChannels.remove(conversationId);
    if (channel != null && _client != null) {
      _client.removeChannel(channel);
    }
    _typingTimers[conversationId]?.cancel();
    _typingTimers.remove(conversationId);
    _typingControllers[conversationId]?.close();
    _typingControllers.remove(conversationId);
  }

  /// Disposes all active WebSocket channels and controllers.
  void dispose() {
    for (final entry in _activeChannels.entries) {
      _client?.removeChannel(entry.value);
    }
    _activeChannels.clear();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    for (final controller in _typingControllers.values) {
      controller.close();
    }
    _typingControllers.clear();
  }
}
