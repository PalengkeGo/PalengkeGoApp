import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';

/// Refund-request processing block for a VENDOR's ORDER DETAILS screen.
///
/// Shown only when the customer has requested a refund (`refundRequested`).
/// The stall holder chooses to approve (money path runs) or decline (order
/// returns to paid). Approve/Decline are differentiated by fill color AND a
/// clear label, so the meaning is never color-only.
class VendorRefundRequestCard extends ConsumerWidget {
  const VendorRefundRequestCard({super.key, required this.order});

  final MarketOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = order.paymentStatus;
    if (payment.name != 'refundRequested') return const SizedBox.shrink();

    final reason = order.refundRequestReason?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REFUND REQUESTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: AppTheme.muted,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Customer asked for a refund',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                reason,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decide(context, ref, approve: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      backgroundColor: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _decide(context, ref, approve: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text(
                      'Approve refund',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Approving issues the refund to the customer’s original payment '
              'method. You can’t undo it.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(approve ? 'Approve refund?' : 'Decline refund?'),
        content: Text(
          approve
              ? 'The customer will receive ${_peso(order.refundedAmount >= order.total - 0.005 ? order.total : order.total - order.refundedAmount)} back to their payment method. Continue?'
              : 'The order returns to paid. The customer can contact support if they disagree.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Go back',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  approve ? AppTheme.primaryGreen : AppTheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(approve ? 'Approve' : 'Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(vendorOrdersProvider.notifier)
          .processRefundRequest(order.id, approve: approve);
      if (!context.mounted) return;
      AppServices.showSnackBar(
        approve ? 'Refund approved.' : 'Refund request declined.',
      );
    } on OrderFailure catch (e) {
      if (!context.mounted) return;
      AppServices.showSnackBar(e.message);
    }
  }

  String _peso(double v) =>
      '₱${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';
}