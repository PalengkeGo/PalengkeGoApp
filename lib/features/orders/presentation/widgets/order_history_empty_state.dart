import 'package:palengkego/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'order_history_tab_row.dart';

class OrderHistoryEmptyState extends StatelessWidget {
  final OrderTab currentTab;

  const OrderHistoryEmptyState({super.key, required this.currentTab});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      iconBackground: const Color(0xFFF2F5F3),
      iconColor: const Color(0xFF9AB4AA),
      iconSize: 34,
      iconContainerRadius: 36,
      iconSpacing: 14,
      title: 'No ${currentTab.label.toLowerCase()} orders yet',
      titleStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF35554A),
      ),
      subtitle: 'Placed orders will show up here automatically.',
      subtitleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFF9AB4AA),
      ),
      subtitleSpacing: 6,
    );
  }
}
