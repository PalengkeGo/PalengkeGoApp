class ChatConversation {
  final String id;
  final String stallId;
  final String stallName;
  final String? stallAvatar;
  final String customerUid;
  final String customerName;
  final String? customerAvatar;
  final String lastMessageText;
  final DateTime lastMessageTimestamp;
  final String lastMessageSenderId;
  final int customerUnreadCount;
  final int vendorUnreadCount;
  final String inquiryType; // 'product' | 'order' | 'delivery' | 'general'
  final String? relatedOrderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatConversation({
    required this.id,
    required this.stallId,
    required this.stallName,
    this.stallAvatar,
    required this.customerUid,
    required this.customerName,
    this.customerAvatar,
    required this.lastMessageText,
    required this.lastMessageTimestamp,
    required this.lastMessageSenderId,
    this.customerUnreadCount = 0,
    this.vendorUnreadCount = 0,
    this.inquiryType = 'general',
    this.relatedOrderId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool hasUnreadForVendor() => vendorUnreadCount > 0;
  bool hasUnreadForCustomer() => customerUnreadCount > 0;

  ChatConversation copyWith({
    String? id,
    String? stallId,
    String? stallName,
    String? stallAvatar,
    String? customerUid,
    String? customerName,
    String? customerAvatar,
    String? lastMessageText,
    DateTime? lastMessageTimestamp,
    String? lastMessageSenderId,
    int? customerUnreadCount,
    int? vendorUnreadCount,
    String? inquiryType,
    String? relatedOrderId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      stallId: stallId ?? this.stallId,
      stallName: stallName ?? this.stallName,
      stallAvatar: stallAvatar ?? this.stallAvatar,
      customerUid: customerUid ?? this.customerUid,
      customerName: customerName ?? this.customerName,
      customerAvatar: customerAvatar ?? this.customerAvatar,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      customerUnreadCount: customerUnreadCount ?? this.customerUnreadCount,
      vendorUnreadCount: vendorUnreadCount ?? this.vendorUnreadCount,
      inquiryType: inquiryType ?? this.inquiryType,
      relatedOrderId: relatedOrderId ?? this.relatedOrderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stallId': stallId,
      'stallName': stallName,
      'stallAvatar': stallAvatar,
      'customerUid': customerUid,
      'customerName': customerName,
      'customerAvatar': customerAvatar,
      'lastMessageText': lastMessageText,
      'lastMessageTimestamp': lastMessageTimestamp.toIso8601String(),
      'lastMessageSenderId': lastMessageSenderId,
      'customerUnreadCount': customerUnreadCount,
      'vendorUnreadCount': vendorUnreadCount,
      'inquiryType': inquiryType,
      'relatedOrderId': relatedOrderId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String? ?? '',
      stallId: json['stallId'] as String? ?? '',
      stallName: json['stallName'] as String? ?? '',
      stallAvatar: json['stallAvatar'] as String?,
      customerUid: json['customerUid'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      customerAvatar: json['customerAvatar'] as String?,
      lastMessageText: json['lastMessageText'] as String? ?? '',
      lastMessageTimestamp: json['lastMessageTimestamp'] != null
          ? DateTime.tryParse(json['lastMessageTimestamp'].toString()) ??
              DateTime.now()
          : DateTime.now(),
      lastMessageSenderId: json['lastMessageSenderId'] as String? ?? '',
      customerUnreadCount: json['customerUnreadCount'] as int? ?? 0,
      vendorUnreadCount: json['vendorUnreadCount'] as int? ?? 0,
      inquiryType: json['inquiryType'] as String? ?? 'general',
      relatedOrderId: json['relatedOrderId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
