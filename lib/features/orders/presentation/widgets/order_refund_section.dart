import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:palengkego/features/orders/presentation/widgets/refund_request_sheet.dart';

/// Refund awareness block for a customer's ORDER DETAILS screen.
///
/// Operate-mode: the customer needs to know (a) they may ask for a refund,
/// (b) their request was received and is being reviewed, or (c) money has come
/// back. Each state names the situation plainly; color is never the only cue.
class OrderRefundSection extends ConsumerWidget {
  const OrderRefundSection({super.key, required this.order});

  final MarketOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = order.paymentStatus;

    // Fully refundable paid order → surface the request action.
    if (payment == PaymentStatus.paid) {
      return _RefundableActionCard(order: order);
    }

    if (payment == PaymentStatus.refundRequested) {
      return _StatusBanner(
        icon: Icons.receipt_long_outlined,
        iconColor: const Color(0xFFB45309),
        tint: const Color(0xFFFFF7ED),
        title: 'Refund requested',
        message: order.refundRequestReason == null ||
                order.refundRequestReason!.isEmpty
            ? 'The stall holder is reviewing your request.'
            : '“${order.refundRequestReason}” — the stall holder is reviewing it.',
        action: 'Awaiting stall holder',
      );
    }

    if (payment == PaymentStatus.refundPending) {
      return const _StatusBanner(
        icon: Icons.hourglass_top,
        iconColor: Color(0xFF166534),
        tint: Color(0xFFF0FDF4),
        title: 'Refund in progress',
        message: 'Your refund is being processed by the payment provider.',
        action: 'Normally settles in a few days',
      );
    }

    if (payment == PaymentStatus.refunded) {
      return _StatusBanner(
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF166534),
        tint: const Color(0xFFF0FDF4),
        title: 'Refunded',
        message: order.refundedAmount >= order.total - 0.005
            ? '${_peso(order.refundedAmount)} was returned to your original payment method.'
            : '${_peso(order.refundedAmount)} of ${_peso(order.total)} was returned.',
        action: 'Payment made',
      );
    }

    // Partial refund while the order remains paid.
    if (payment == PaymentStatus.paid && order.refundedAmount > 0) {
      return _StatusBanner(
        icon: Icons.payments_outlined,
        iconColor: const Color(0xFF166534),
        tint: const Color(0xFFF0FDF4),
        title: 'Partially refunded',
        message:
            '${_peso(order.refundedAmount)} of ${_peso(order.total)} has been returned to your payment method.',
        action: 'Payment made',
      );
    }

    return const SizedBox.shrink();
  }

  String _peso(double v) =>
      '₱${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';
}

class _RefundableActionCard extends StatelessWidget {
  const _RefundableActionCard({required this.order});

  final MarketOrder order;

  @override
  Widget build(BuildContext context) {
    final refundable = order.total - order.refundedAmount;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need a refund?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  refundable >= order.total - 0.005
                      ? 'You paid ${_peso(order.total)} for this order.'
                      : '${_peso(refundable)} left to refund of ${_peso(order.total)}.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final done = await showRefundRequestSheet(context, order);
              if (done == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Refund request sent. The stall holder will review it.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Request'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryGreen,
              side: const BorderSide(color: AppTheme.primaryGreen),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _peso(double v) =>
      '₱${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.iconColor,
    required this.tint,
    required this.title,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color tint;
  final String title;
  final String message;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: iconColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      action,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppTheme.textSecondary,
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