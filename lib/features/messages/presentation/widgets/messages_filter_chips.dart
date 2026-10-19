import 'package:flutter/material.dart';
import 'package:palengkego/core/theme/app_theme.dart';

enum MessageFilter { all, unread, orders }

class MessagesFilterChips extends StatelessWidget {
  final MessageFilter selectedFilter;
  final ValueChanged<MessageFilter> onSelected;
  final int allCount;
  final int unreadCount;
  final int ordersCount;

  const MessagesFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onSelected,
    required this.allCount,
    required this.unreadCount,
    required this.ordersCount,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(
            filter: MessageFilter.all,
            label: 'All ($allCount)',
          ),
          const SizedBox(width: 8),
          _buildChip(
            filter: MessageFilter.unread,
            label: 'Unread ($unreadCount)',
          ),
          const SizedBox(width: 8),
          _buildChip(
            filter: MessageFilter.orders,
            label: 'Orders ($ordersCount)',
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required MessageFilter filter,
    required String label,
  }) {
    final isSelected = selectedFilter == filter;

    return GestureDetector(
      onTap: () => onSelected(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryGreen
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
