import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';
import 'vendor_order_status_badge.dart';

/// Order header card: status pill, timestamp, priority banner, ETA + edit.
class VendorOrderHeaderCard extends ConsumerWidget {
  const VendorOrderHeaderCard({super.key, required this.order});

  final MarketOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.isPriority) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 18, color: AppTheme.warning),
                  SizedBox(width: 6),
                  Text(
                    'PRIORITY ORDER — Expedite Preparation',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order ${order.id}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              VendorOrderStatusBadge(
                status: order.status,
                isPickup: order.isPickup,
                fontSize: 12,
                horizontalPadding: 10,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMM d, yyyy - hh:mm a').format(order.placedAt),
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          if (order.status == OrderStatus.preparing ||
              order.status == OrderStatus.ready) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 18,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.estimatedReadyTime != null
                          ? 'Ready at ${DateFormat('hh:mm a').format(order.estimatedReadyTime!)}'
                          : 'Estimated Ready Time not set',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                if (order.status == OrderStatus.preparing)
                  InkWell(
                    onTap: () async {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null && context.mounted) {
                        final now = DateTime.now();
                        final estimatedTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          time.hour,
                          time.minute,
                        );
                        try {
                          await ref
                              .read(vendorOrdersProvider.notifier)
                              .updateEstimatedReadyTime(
                                order.id,
                                estimatedTime,
                                order.status,
                              );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Estimated ready time updated.'),
                            ),
                          );
                        } on OrderFailure catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.message),
                              backgroundColor: const Color(0xFFB3261E),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 20,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                order.customerName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
