import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';

/// Report / Block actions shown for completed or cancelled orders.
class OrderDetailsStallActions extends StatelessWidget {
  final MarketOrder order;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  const OrderDetailsStallActions({
    super.key,
    required this.order,
    required this.onReport,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    if (order.status != OrderStatus.completed &&
        order.status != OrderStatus.cancelled) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stall Holder Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'Report Stall Holder',
                  icon: Icons.flag_outlined,
                  backgroundColor: Colors.white,
                  textColor: const Color(0xFFF59E0B),
                  borderColor: const Color(0xFFFDE68A),
                  onTap: onReport,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  label: 'Block Stall Holder',
                  icon: Icons.block,
                  backgroundColor: const Color(0xFFFEF2F2),
                  textColor: const Color(0xFFDC2626),
                  borderColor: const Color(0xFFFECACA),
                  onTap: onBlock,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
