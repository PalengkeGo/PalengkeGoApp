import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/messages/domain/chat_conversation.dart';

class ConversationCard extends StatelessWidget {
  final ChatConversation conversation;
  final bool isVendorView;
  final VoidCallback onTap;

  const ConversationCard({
    super.key,
    required this.conversation,
    required this.isVendorView,
    required this.onTap,
  });

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(messageDate).inDays;

    if (diffDays == 0) {
      return DateFormat('h:mm a').format(dt);
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else if (dt.year == now.year) {
      return DateFormat('MMM d').format(dt);
    } else {
      return DateFormat('MMM d, yyyy').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = isVendorView
        ? conversation.customerName
        : conversation.stallName;
    final unreadCount = isVendorView
        ? conversation.vendorUnreadCount
        : conversation.customerUnreadCount;
    final hasUnread = unreadCount > 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread
                ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                : AppTheme.border,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            _buildAvatar(displayName),
            const SizedBox(width: 12),
            // Middle Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasUnread
                                ? FontWeight.w800
                                : FontWeight.w700,
                            color: AppTheme.primaryGreen,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(conversation.lastMessageTimestamp),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w500,
                          color: hasUnread
                              ? AppTheme.primaryGreen
                              : AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Last message preview + unread badge + chevron
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessageText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.w400,
                            color: hasUnread
                                ? const Color(0xFF1E293B)
                                : AppTheme.textSecondary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.muted,
                        size: 20,
                      ),
                    ],
                  ),
                  // Tag Chip
                  if (conversation.inquiryType.isNotEmpty &&
                      conversation.inquiryType != 'general') ...[
                    const SizedBox(height: 8),
                    _buildTagChip(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final initials = name.trim().isNotEmpty
        ? name
            .trim()
            .split(RegExp(r'\s+'))
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'PG';

    // Generates a soft pastel background based on name hash
    final colors = [
      const Color(0xFFE0E7FF),
      const Color(0xFFDCFCE7),
      const Color(0xFFFEF3C7),
      const Color(0xFFFCE7F3),
      const Color(0xFFE0F2FE),
    ];
    final textColors = [
      const Color(0xFF3730A3),
      const Color(0xFF166534),
      const Color(0xFFB45309),
      const Color(0xFF9D174D),
      const Color(0xFF0369A1),
    ];
    final colorIndex = name.hashCode.abs() % colors.length;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: colors[colorIndex],
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textColors[colorIndex],
        ),
      ),
    );
  }

  Widget _buildTagChip() {
    IconData icon;
    String label;
    Color bgColor;
    Color fgColor;

    if (conversation.inquiryType == 'order') {
      icon = Icons.receipt_long_outlined;
      label = conversation.relatedOrderId != null
          ? 'Order #${conversation.relatedOrderId}'
          : 'Order inquiry';
      bgColor = const Color(0xFFDCFCE7);
      fgColor = const Color(0xFF166534);
    } else if (conversation.inquiryType == 'delivery') {
      icon = Icons.local_shipping_outlined;
      label = 'Delivery inquiry';
      bgColor = const Color(0xFFFEF3C7);
      fgColor = const Color(0xFFB45309);
    } else {
      icon = Icons.shopping_cart_outlined;
      label = 'Product inquiry';
      bgColor = const Color(0xFFEEF2FF);
      fgColor = const Color(0xFF4338CA);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fgColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}
