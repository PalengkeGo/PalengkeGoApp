import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:palengkego/features/messages/domain/chat_conversation.dart';
import 'package:palengkego/features/messages/domain/chat_message.dart';

final sharedMessagingStoreProvider = Provider<SharedMessagingStore>(
  (ref) => SharedMessagingStore(),
);

class SharedMessagingStore {
  SharedMessagingStore();

  final List<ChatConversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messages = {};
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const _conversationsKey = 'mock_chat_conversations_v1';
  static const _messagesKey = 'mock_chat_messages_v1';

  final _conversationsStreamController =
      StreamController<List<ChatConversation>>.broadcast();
  final Map<String, StreamController<List<ChatMessage>>>
      _messageStreamControllers = {};

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;
  Future<void>? _pendingSave;

  List<ChatConversation> get conversations =>
      List.unmodifiable(_conversations);

  List<ChatMessage> getMessages(String conversationId) =>
      List.unmodifiable(_messages[conversationId] ?? []);

  Stream<List<ChatConversation>> watchConversations() {
    // Emit initial cached state immediately on listen
    return _conversationsStreamController.stream;
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    if (!_messageStreamControllers.containsKey(conversationId)) {
      _messageStreamControllers[conversationId] =
          StreamController<List<ChatMessage>>.broadcast();
    }
    return _messageStreamControllers[conversationId]!.stream;
  }

  void _notifyConversations() {
    _conversations.sort(
      (a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp),
    );
    _conversationsStreamController.add(List.unmodifiable(_conversations));
  }

  void _notifyMessages(String conversationId) {
    final list = _messages[conversationId] ?? [];
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (_messageStreamControllers.containsKey(conversationId)) {
      _messageStreamControllers[conversationId]!
          .add(List.unmodifiable(list));
    }
  }

  Future<void> load({bool force = false}) async {
    if (_pendingSave != null) {
      await _pendingSave;
    }
    if (_isLoaded && !force) {
      _notifyConversations();
      return;
    }

    String? conversationsJson;
    String? messagesJson;
    try {
      conversationsJson = await _storage.read(key: _conversationsKey);
      messagesJson = await _storage.read(key: _messagesKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SharedMessagingStore: Secure storage unavailable: $e');
      }
    }

    if (conversationsJson != null && messagesJson != null) {
      _conversations.clear();
      _messages.clear();
      try {
        final List<dynamic> decodedConv = jsonDecode(conversationsJson);
        _conversations.addAll(
          decodedConv.map(
            (item) => ChatConversation.fromJson(item as Map<String, dynamic>),
          ),
        );

        final Map<String, dynamic> decodedMsgs = jsonDecode(messagesJson);
        decodedMsgs.forEach((convId, msgsList) {
          final list = msgsList as List<dynamic>;
          _messages[convId] = list
              .map(
                (item) => ChatMessage.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        });

        _isLoaded = true;
        _notifyConversations();
        for (final id in _messages.keys) {
          _notifyMessages(id);
        }
        return;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('SharedMessagingStore: Error parsing stored data: $e');
        }
      }
    }

    // Initialize with reference mock conversations
    _initDefaultData();
    _isLoaded = true;
    _notifyConversations();
    for (final id in _messages.keys) {
      _notifyMessages(id);
    }
    await save();
  }

  void _initDefaultData() {
    _conversations.clear();
    _messages.clear();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // 1. Ana Santos
    final anaTime4 =
        now.isAfter(today.add(const Duration(hours: 10, minutes: 24)))
            ? today.add(const Duration(hours: 10, minutes: 24))
            : now.subtract(const Duration(minutes: 5));
    final anaTime3 = anaTime4.subtract(const Duration(minutes: 1));
    final anaTime2 = anaTime4.subtract(const Duration(minutes: 3));
    final anaTime1 = anaTime4.subtract(const Duration(minutes: 4));

    final convAna = ChatConversation(
      id: 'conv_ana_santos',
      stallId: 'v1',
      stallName: "Mer's Mayao Fruit Stand",
      customerUid: 'cust_ana_santos',
      customerName: 'Ana Santos',
      lastMessageText:
          'Hi! Available pa po ba ang lakatan bananas today? Gaano po ang kilo?',
      lastMessageTimestamp: anaTime4,
      lastMessageSenderId: 'cust_ana_santos',
      vendorUnreadCount: 2,
      customerUnreadCount: 0,
      inquiryType: 'product',
      createdAt: anaTime1,
      updatedAt: anaTime4,
    );
    _conversations.add(convAna);
    _messages[convAna.id] = [
      ChatMessage(
        id: 'msg_ana_1',
        conversationId: convAna.id,
        senderId: 'cust_ana_santos',
        senderName: 'Ana Santos',
        senderRole: 'customer',
        text: "Good morning po! Mer's Mayao Fruit Stand po ba ito?",
        timestamp: anaTime1,
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_ana_2',
        conversationId: convAna.id,
        senderId: 'v1',
        senderName: "Mer's Mayao Fruit Stand",
        senderRole: 'vendor',
        text: "Opo ma'am! Welcome po sa Mer's Mayao Fruit Stand. Ano pong kailangan nila?",
        timestamp: anaTime2,
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_ana_3',
        conversationId: convAna.id,
        senderId: 'cust_ana_santos',
        senderName: 'Ana Santos',
        senderRole: 'customer',
        text: 'Tatanong ko lang po if fresh yung lakatan bananas niyo.',
        timestamp: anaTime3,
        isRead: false,
      ),
      ChatMessage(
        id: 'msg_ana_4',
        conversationId: convAna.id,
        senderId: 'cust_ana_santos',
        senderName: 'Ana Santos',
        senderRole: 'customer',
        text:
            'Hi! Available pa po ba ang lakatan bananas today? Gaano po ang kilo?',
        timestamp: anaTime4,
        isRead: false,
      ),
    ];

    // 2. Mark Dela Cruz
    final markTime3 =
        now.isAfter(today.add(const Duration(hours: 9, minutes: 18)))
            ? today.add(const Duration(hours: 9, minutes: 18))
            : now.subtract(const Duration(minutes: 45));
    final markTime2 = markTime3.subtract(const Duration(minutes: 2));
    final markTime1 = markTime3.subtract(const Duration(minutes: 3));
    final convMark = ChatConversation(
      id: 'conv_mark_dela_cruz',
      stallId: 'v1',
      stallName: "Mer's Mayao Fruit Stand",
      customerUid: 'cust_mark_dela_cruz',
      customerName: 'Mark Dela Cruz',
      lastMessageText:
          'Thank you po! Confirmed na po ang order ko. Kailan po pwede pickup?',
      lastMessageTimestamp: markTime3,
      lastMessageSenderId: 'cust_mark_dela_cruz',
      vendorUnreadCount: 1,
      customerUnreadCount: 0,
      inquiryType: 'order',
      relatedOrderId: '1024',
      createdAt: markTime1,
      updatedAt: markTime3,
    );
    _conversations.add(convMark);
    _messages[convMark.id] = [
      ChatMessage(
        id: 'msg_mark_1',
        conversationId: convMark.id,
        senderId: 'cust_mark_dela_cruz',
        senderName: 'Mark Dela Cruz',
        senderRole: 'customer',
        text: 'Hello po, nag-place po ako ng order #1024 sa inyong stall.',
        timestamp: markTime1,
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_mark_2',
        conversationId: convMark.id,
        senderId: 'v1',
        senderName: "Mer's Mayao Fruit Stand",
        senderRole: 'vendor',
        text: 'Noted po sir Mark, check po namin sa order list.',
        timestamp: markTime2,
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_mark_3',
        conversationId: convMark.id,
        senderId: 'cust_mark_dela_cruz',
        senderName: 'Mark Dela Cruz',
        senderRole: 'customer',
        text:
            'Thank you po! Confirmed na po ang order ko. Kailan po pwede pickup?',
        timestamp: markTime3,
        isRead: false,
      ),
    ];

    // 3. Liza Reyes
    final lizaTime1 = yesterday.add(const Duration(hours: 15, minutes: 40));
    final lizaTime2 = yesterday.add(const Duration(hours: 15, minutes: 45));
    final convLiza = ChatConversation(
      id: 'conv_liza_reyes',
      stallId: 'v1',
      stallName: "Mer's Mayao Fruit Stand",
      customerUid: 'cust_liza_reyes',
      customerName: 'Liza Reyes',
      lastMessageText:
          'Do you have fresh tomatoes and onions today? Pwede po pa-reserve ng 2 kilos each?',
      lastMessageTimestamp: lizaTime2,
      lastMessageSenderId: 'cust_liza_reyes',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      inquiryType: 'product',
      createdAt: lizaTime1,
      updatedAt: lizaTime2,
    );
    _conversations.add(convLiza);
    _messages[convLiza.id] = [
      ChatMessage(
        id: 'msg_liza_1',
        conversationId: convLiza.id,
        senderId: 'cust_liza_reyes',
        senderName: 'Liza Reyes',
        senderRole: 'customer',
        text:
            'Do you have fresh tomatoes and onions today? Pwede po pa-reserve ng 2 kilos each?',
        timestamp: lizaTime2,
        isRead: true,
      ),
    ];

    // 4. John Carlo
    final johnTime1 = yesterday.add(const Duration(hours: 13, minutes: 15));
    final convJohn = ChatConversation(
      id: 'conv_john_carlo',
      stallId: 'v1',
      stallName: "Mer's Mayao Fruit Stand",
      customerUid: 'cust_john_carlo',
      customerName: 'John Carlo',
      lastMessageText:
          "Hi po, ask ko lang if you offer delivery? I'm around Makati po.",
      lastMessageTimestamp: johnTime1,
      lastMessageSenderId: 'cust_john_carlo',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      inquiryType: 'delivery',
      createdAt: johnTime1,
      updatedAt: johnTime1,
    );
    _conversations.add(convJohn);
    _messages[convJohn.id] = [
      ChatMessage(
        id: 'msg_john_1',
        conversationId: convJohn.id,
        senderId: 'cust_john_carlo',
        senderName: 'John Carlo',
        senderRole: 'customer',
        text:
            "Hi po, ask ko lang if you offer delivery? I'm around Makati po.",
        timestamp: johnTime1,
        isRead: true,
      ),
    ];

    // 5. Mara Villanueva
    final maraTime = DateTime(now.year, 7, 10, 11, 30);
    final convMara = ChatConversation(
      id: 'conv_mara_villanueva',
      stallId: 'v1',
      stallName: "Mer's Mayao Fruit Stand",
      customerUid: 'cust_mara_villanueva',
      customerName: 'Mara Villanueva',
      lastMessageText:
          'Kumusta po? Available pa po ba ang bagoong and sampalok?',
      lastMessageTimestamp: maraTime,
      lastMessageSenderId: 'cust_mara_villanueva',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      inquiryType: 'product',
      createdAt: maraTime,
      updatedAt: maraTime,
    );
    _conversations.add(convMara);
    _messages[convMara.id] = [
      ChatMessage(
        id: 'msg_mara_1',
        conversationId: convMara.id,
        senderId: 'cust_mara_villanueva',
        senderName: 'Mara Villanueva',
        senderRole: 'customer',
        text: 'Kumusta po? Available pa po ba ang bagoong and sampalok?',
        timestamp: maraTime,
        isRead: true,
      ),
    ];

    // 6. Carlo Mendoza
    final carloTime = DateTime(now.year, 7, 9, 16, 20);
    final convCarlo = ChatConversation(
      id: 'conv_carlo_mendoza',
      stallId: 'v1',
      stallName: "Mer's Mayao Fruit Stand",
      customerUid: 'cust_carlo_mendoza',
      customerName: 'Carlo Mendoza',
      lastMessageText:
          'Nareceive ko na po yung order. Fresh and good quality! Salamat po!',
      lastMessageTimestamp: carloTime,
      lastMessageSenderId: 'cust_carlo_mendoza',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      inquiryType: 'order',
      relatedOrderId: '1018',
      createdAt: carloTime,
      updatedAt: carloTime,
    );
    _conversations.add(convCarlo);
    _messages[convCarlo.id] = [
      ChatMessage(
        id: 'msg_carlo_1',
        conversationId: convCarlo.id,
        senderId: 'cust_carlo_mendoza',
        senderName: 'Carlo Mendoza',
        senderRole: 'customer',
        text:
            'Nareceive ko na po yung order. Fresh and good quality! Salamat po!',
        timestamp: carloTime,
        isRead: true,
      ),
    ];

    // 7. Elena Cruz (Order #1012)
    final elenaTime = DateTime(now.year, 7, 5, 14, 10);
    final convElena = ChatConversation(
      id: 'conv_elena_cruz',
      stallId: 'v1',
      stallName: "Mer's Mayao Fruit Stand",
      customerUid: 'cust_elena_cruz',
      customerName: 'Elena Cruz',
      lastMessageText: 'Order #1012 has been received. Thank you po!',
      lastMessageTimestamp: elenaTime,
      lastMessageSenderId: 'cust_elena_cruz',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      inquiryType: 'order',
      relatedOrderId: '1012',
      createdAt: elenaTime,
      updatedAt: elenaTime,
    );
    _conversations.add(convElena);
    _messages[convElena.id] = [
      ChatMessage(
        id: 'msg_elena_1',
        conversationId: convElena.id,
        senderId: 'cust_elena_cruz',
        senderName: 'Elena Cruz',
        senderRole: 'customer',
        text: 'Order #1012 has been received. Thank you po!',
        timestamp: elenaTime,
        isRead: true,
      ),
    ];

    // 8. Roberto Tan (Order #1009)
    final robertoTime = DateTime(now.year, 7, 3, 10, 05);
    final convRoberto = ChatConversation(
      id: 'conv_roberto_tan',
      stallId: 'v1',
      stallName: "Mer's Mayao Fruit Stand",
      customerUid: 'cust_roberto_tan',
      customerName: 'Roberto Tan',
      lastMessageText: 'Paki-double check po yung weight ng order #1009.',
      lastMessageTimestamp: robertoTime,
      lastMessageSenderId: 'cust_roberto_tan',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      inquiryType: 'order',
      relatedOrderId: '1009',
      createdAt: robertoTime,
      updatedAt: robertoTime,
    );
    _conversations.add(convRoberto);
    _messages[convRoberto.id] = [
      ChatMessage(
        id: 'msg_roberto_1',
        conversationId: convRoberto.id,
        senderId: 'cust_roberto_tan',
        senderName: 'Roberto Tan',
        senderRole: 'customer',
        text: 'Paki-double check po yung weight ng order #1009.',
        timestamp: robertoTime,
        isRead: true,
      ),
    ];

    // 9. Grace Lim (Order #1005)
    final graceTime = DateTime(now.year, 6, 28, 16, 45);
    final convGrace = ChatConversation(
      id: 'conv_grace_lim',
      stallId: 'v1',
      stallName: "Mer's Mayao Fruit Stand",
      customerUid: 'cust_grace_lim',
      customerName: 'Grace Lim',
      lastMessageText: 'Salamat po sa fast preparation ng order #1005!',
      lastMessageTimestamp: graceTime,
      lastMessageSenderId: 'cust_grace_lim',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      inquiryType: 'order',
      relatedOrderId: '1005',
      createdAt: graceTime,
      updatedAt: graceTime,
    );
    _conversations.add(convGrace);
    _messages[convGrace.id] = [
      ChatMessage(
        id: 'msg_grace_1',
        conversationId: convGrace.id,
        senderId: 'cust_grace_lim',
        senderName: 'Grace Lim',
        senderRole: 'customer',
        text: 'Salamat po sa fast preparation ng order #1005!',
        timestamp: graceTime,
        isRead: true,
      ),
    ];

    // 10. Patricia Diaz (Product)
    final patriciaTime = DateTime(now.year, 6, 25, 9, 30);
    final convPatricia = ChatConversation(
      id: 'conv_patricia_diaz',
      stallId: 'v1',
      stallName: "Mer's Mayao Fruit Stand",
      customerUid: 'cust_patricia_diaz',
      customerName: 'Patricia Diaz',
      lastMessageText: 'May available pa po bang ripe mangoes by next week?',
      lastMessageTimestamp: patriciaTime,
      lastMessageSenderId: 'cust_patricia_diaz',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      inquiryType: 'product',
      createdAt: patriciaTime,
      updatedAt: patriciaTime,
    );
    _conversations.add(convPatricia);
    _messages[convPatricia.id] = [
      ChatMessage(
        id: 'msg_patricia_1',
        conversationId: convPatricia.id,
        senderId: 'cust_patricia_diaz',
        senderName: 'Patricia Diaz',
        senderRole: 'customer',
        text: 'May available pa po bang ripe mangoes by next week?',
        timestamp: patriciaTime,
        isRead: true,
      ),
    ];

    // 11. Dennis Reyes (Delivery)
    final dennisTime = DateTime(now.year, 6, 20, 13, 10);
    final convDennis = ChatConversation(
      id: 'conv_dennis_reyes',
      stallId: 'v1',
      stallName: "Mer's Mayao Fruit Stand",
      customerUid: 'cust_dennis_reyes',
      customerName: 'Dennis Reyes',
      lastMessageText: 'Available po ba for afternoon delivery?',
      lastMessageTimestamp: dennisTime,
      lastMessageSenderId: 'cust_dennis_reyes',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      inquiryType: 'delivery',
      createdAt: dennisTime,
      updatedAt: dennisTime,
    );
    _conversations.add(convDennis);
    _messages[convDennis.id] = [
      ChatMessage(
        id: 'msg_dennis_1',
        conversationId: convDennis.id,
        senderId: 'cust_dennis_reyes',
        senderName: 'Dennis Reyes',
        senderRole: 'customer',
        text: 'Available po ba for afternoon delivery?',
        timestamp: dennisTime,
        isRead: true,
      ),
    ];

    // 12. Maria Santos (Product)
    final mariaTime = DateTime(now.year, 6, 15, 11, 00);
    final convMaria = ChatConversation(
      id: 'conv_maria_santos',
      stallId: 'v1',
      stallName: "Mer's Mayao Fruit Stand",
      customerUid: 'cust_maria_santos',
      customerName: 'Maria Santos',
      lastMessageText: 'Hi po! Magkano po ang per box ng orange?',
      lastMessageTimestamp: mariaTime,
      lastMessageSenderId: 'cust_maria_santos',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      inquiryType: 'product',
      createdAt: mariaTime,
      updatedAt: mariaTime,
    );
    _conversations.add(convMaria);
    _messages[convMaria.id] = [
      ChatMessage(
        id: 'msg_maria_1',
        conversationId: convMaria.id,
        senderId: 'cust_maria_santos',
        senderName: 'Maria Santos',
        senderRole: 'customer',
        text: 'Hi po! Magkano po ang per box ng orange?',
        timestamp: mariaTime,
        isRead: true,
      ),
    ];
  }

  Future<void> save() async {
    final saveFuture = _performSave();
    _pendingSave = saveFuture;
    try {
      await saveFuture;
    } finally {
      if (_pendingSave == saveFuture) {
        _pendingSave = null;
      }
    }
  }

  Future<void> _performSave() async {
    try {
      final serializedConv = _conversations.map((c) => c.toJson()).toList();
      final convJson = jsonEncode(serializedConv);

      final Map<String, dynamic> serializedMsgs = _messages.map((key, value) {
        return MapEntry(key, value.map((m) => m.toJson()).toList());
      });
      final msgsJson = jsonEncode(serializedMsgs);

      await _storage.write(key: _conversationsKey, value: convJson);
      await _storage.write(key: _messagesKey, value: msgsJson);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SharedMessagingStore: Error saving data: $e');
      }
    }
  }

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
    await load();
    final normalizedStallId =
        (stallId == 'stall holder-001' || stallId == 'vendor-001')
            ? 'v1'
            : stallId;

    // Check existing conversation
    final index = _conversations.indexWhere(
      (c) =>
          c.customerUid == customerUid &&
          (c.stallId == normalizedStallId ||
              c.stallId == stallId ||
              (normalizedStallId == 'v1' &&
                  (c.stallId == 'v1' ||
                      c.stallId == 'stall holder-001' ||
                      c.stallId == 'vendor-001'))),
    );

    if (index != -1) {
      return _conversations[index];
    }

    // Create new conversation
    final now = DateTime.now();
    final newConv = ChatConversation(
      id: 'conv_${customerUid}_$normalizedStallId',
      stallId: normalizedStallId,
      stallName: stallName,
      stallAvatar: stallAvatar,
      customerUid: customerUid,
      customerName: customerName,
      customerAvatar: customerAvatar,
      lastMessageText: 'Started a conversation',
      lastMessageTimestamp: now,
      lastMessageSenderId: customerUid,
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      inquiryType: inquiryType,
      relatedOrderId: relatedOrderId,
      createdAt: now,
      updatedAt: now,
    );

    _conversations.insert(0, newConv);
    _messages[newConv.id] = [];
    _notifyConversations();
    _notifyMessages(newConv.id);
    await save();
    return newConv;
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    await load();
    final now = DateTime.now();
    final message = ChatMessage(
      id: 'msg_${now.millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      text: text.trim(),
      timestamp: now,
      isRead: false,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType ?? (attachmentUrl != null ? 'image' : null),
    );

    final msgs = _messages.putIfAbsent(conversationId, () => []);
    msgs.add(message);

    // Update conversation record
    final convIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convIndex != -1) {
      final existing = _conversations[convIndex];
      final isFromVendor = senderRole == 'vendor';
      final previewText = message.text.isNotEmpty
          ? message.text
          : (message.attachmentUrl != null ? '📷 Photo' : '');
      final updated = existing.copyWith(
        lastMessageText: previewText,
        lastMessageTimestamp: now,
        lastMessageSenderId: senderId,
        vendorUnreadCount: isFromVendor
            ? existing.vendorUnreadCount
            : existing.vendorUnreadCount + 1,
        customerUnreadCount: isFromVendor
            ? existing.customerUnreadCount + 1
            : existing.customerUnreadCount,
        updatedAt: now,
      );
      _conversations[convIndex] = updated;
    }

    _notifyMessages(conversationId);
    _notifyConversations();
    await save();
    return message;
  }

  Future<void> markAsRead({
    required String conversationId,
    required String readerRole,
  }) async {
    await load();
    final msgs = _messages[conversationId];
    if (msgs != null) {
      bool changed = false;
      final updatedMsgs = msgs.map((m) {
        if (!m.isRead &&
            ((readerRole == 'vendor' && m.senderRole == 'customer') ||
                (readerRole == 'customer' && m.senderRole == 'vendor'))) {
          changed = true;
          return m.copyWith(isRead: true, readAt: DateTime.now());
        }
        return m;
      }).toList();

      if (changed) {
        _messages[conversationId] = updatedMsgs;
        _notifyMessages(conversationId);
      }
    }

    final convIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convIndex != -1) {
      final existing = _conversations[convIndex];
      final updated = existing.copyWith(
        vendorUnreadCount: readerRole == 'vendor' ? 0 : existing.vendorUnreadCount,
        customerUnreadCount:
            readerRole == 'customer' ? 0 : existing.customerUnreadCount,
      );
      _conversations[convIndex] = updated;
      _notifyConversations();
    }

    await save();
  }

  int getVendorUnreadCount(String stallId) {
    final normalizedStallId =
        (stallId == 'stall holder-001' || stallId == 'vendor-001')
            ? 'v1'
            : stallId;
    return _conversations
        .where((c) =>
            c.stallId == normalizedStallId ||
            c.stallId == stallId ||
            (normalizedStallId == 'v1' &&
                (c.stallId == 'v1' ||
                    c.stallId == 'stall holder-001' ||
                    c.stallId == 'vendor-001')))
        .where((c) => c.vendorUnreadCount > 0)
        .length;
  }

  int getCustomerUnreadCount(String customerUid) {
    return _conversations
        .where((c) => c.customerUid == customerUid)
        .where((c) => c.customerUnreadCount > 0)
        .length;
  }

  void dispose() {
    _conversationsStreamController.close();
    for (final controller in _messageStreamControllers.values) {
      controller.close();
    }
  }
}
