import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'vendor_order_dialogs.dart';

/// Customer actions (report/block) or the cancel action for the order.
class VendorOrderActions extends ConsumerWidget {
  const VendorOrderActions({super.key, required this.order});

  final MarketOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHistory =
        order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.rejected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isHistory) ...[
          const Text(
            'Customer Actions',
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
                child: _ActionButton(
                  label: 'Report Issue',
                  icon: Icons.flag_outlined,
                  backgroundColor: Colors.white,
                  textColor: const Color(0xFFF59E0B),
                  borderColor: const Color(0xFFFDE68A),
                  onTap: () => showVendorReportCustomerDialog(context, order),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: 'Block Customer',
                  icon: Icons.block_outlined,
                  backgroundColor: const Color(0xFFFEF2F2),
                  textColor: const Color(0xFFEF4444),
                  borderColor: const Color(0xFFFECACA),
                  onTap: () => showVendorBlockCustomerDialog(context, order),
                ),
              ),
            ],
          ),
        ],
        if (!isHistory) ...[
          SizedBox(
            width: double.infinity,
            child: _ActionButton(
              label: 'Cancel Order',
              icon: Icons.cancel_outlined,
              backgroundColor: Colors.white,
              textColor: const Color(0xFFEF4444),
              borderColor: const Color(0xFFFECACA),
              onTap: () => showVendorCancelOrderDialog(context, ref, order),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
