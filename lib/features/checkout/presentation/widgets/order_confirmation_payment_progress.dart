import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/checkout/application/checkout_controller.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:url_launcher/url_launcher.dart';

/// Payment progress for orders placed with an online method (GCash/Maya).
///
/// Shows one row per order that still needs the customer's approval in the
/// e-wallet app: a "Complete Payment" button opens the PayMongo redirect
/// (when there is one), otherwise the payment is already processing and the
/// verified webhook flips the order's status — the row says exactly that.
/// Failed initiations get a retry.
class OrderConfirmationPaymentProgress extends ConsumerStatefulWidget {
  const OrderConfirmationPaymentProgress({super.key});

  @override
  ConsumerState<OrderConfirmationPaymentProgress> createState() =>
      _OrderConfirmationPaymentProgressState();
}

class _OrderConfirmationPaymentProgressState
    extends ConsumerState<OrderConfirmationPaymentProgress>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // PayMongo redirects outside the app; refresh once when the user
      // returns so the webhook-updated payment status is shown.
      ref.read(orderServiceProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentSessions = ref.watch(
      checkoutProvider.select((s) => s.paymentSessions),
    );
    final paymentFailures = ref.watch(
      checkoutProvider.select((s) => s.paymentFailures),
    );
    final paidOrderIds = (ref.watch(orderServiceProvider).value ?? const [])
        .where((order) => order.paymentStatus == PaymentStatus.paid)
        .map((order) => order.id)
        .toSet();
    if (paymentSessions.isEmpty && paymentFailures.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = <Widget>[];
    for (final entry in paymentSessions.entries) {
      if (!paidOrderIds.contains(entry.key)) {
        rows.add(_SessionRow(orderId: entry.key, redirectUrl: entry.value));
      }
    }
    for (final entry in paymentFailures.entries) {
      rows.add(_FailureRow(orderId: entry.key, reason: entry.value));
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Online Payment',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your orders are reserved. Complete the e-wallet approval — the '
            'status updates automatically once PayMongo confirms.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.orderId, this.redirectUrl});

  final String orderId;
  final String? redirectUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortId = orderId.length > 8
        ? orderId.substring(0, 8)
        : orderId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFFB54708)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              redirectUrl == null
                  ? 'Order $shortId — payment processing, no action needed.'
                  : 'Order $shortId — awaiting your approval.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            ),
          ),
          if (redirectUrl != null)
            TextButton(
              onPressed: () async {
                await _launch(redirectUrl!);
                await ref.read(orderServiceProvider.notifier).refresh();
              },
              child: const Text('Complete Payment'),
            ),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    try {
      final uri = Uri.parse(url);
      // Best-effort: if the device has no browser, the button remains.
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No handler / no browser — the user can retry or pay at the stall.
    }
  }
}

class _FailureRow extends ConsumerWidget {
  const _FailureRow({required this.orderId, required this.reason});

  final String orderId;
  final String reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: Color(0xFFB42318)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Order $shortId — $reason',
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(checkoutProvider.notifier).retryPayment(orderId),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
