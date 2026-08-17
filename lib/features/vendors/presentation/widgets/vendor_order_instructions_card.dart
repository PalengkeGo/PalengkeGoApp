import 'package:flutter/material.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';

/// Special instructions card with empty-state copy.
class VendorOrderInstructionsCard extends StatelessWidget {
  const VendorOrderInstructionsCard({super.key, required this.order});

  final MarketOrder order;

  bool get _hasNotes => order.notes != null && order.notes!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _hasNotes
            ? const Color(0xFFFEF3C7).withValues(alpha: 0.4)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasNotes ? const Color(0xFFFEF3C7) : AppTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 20,
            color: _hasNotes ? const Color(0xFFD97706) : AppTheme.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasNotes
                      ? order.notes!
                      : 'No special instructions provided by the customer.',
                  style: TextStyle(
                    fontSize: 14,
                    color: _hasNotes
                        ? const Color(0xFF78350F)
                        : AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
