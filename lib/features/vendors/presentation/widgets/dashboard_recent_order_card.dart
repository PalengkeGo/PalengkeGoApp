import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class DashboardRecentOrderCard extends StatelessWidget {
  final String orderId;
  final String customer;
  final String items;
  final String total;
  final String time;
  final String primaryActionText;
  final VoidCallback onPrimaryAction;

  /// Customer's delivery mode, e.g. 'Standard Delivery', 'Priority Delivery'
  /// or 'Pick-Up'. Optional — hidden when not provided.
  final String? deliveryMode;

  /// Whether the customer opted for priority delivery at checkout.
  final bool isPriority;

  const DashboardRecentOrderCard({
    super.key,
    required this.orderId,
    required this.customer,
    required this.items,
    required this.total,
    required this.time,
    this.primaryActionText = 'Start Preparing',
    required this.onPrimaryAction,
    this.deliveryMode,
    this.isPriority = false,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderId,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                total,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            items,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (deliveryMode != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  deliveryMode == 'Pick-Up'
                      ? Icons.storefront_outlined
                      : Icons.local_shipping_outlined,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  deliveryMode!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isPriority ? FontWeight.w700 : FontWeight.w500,
                    color: isPriority ? AppTheme.warning : AppTheme.textSecondary,
                  ),
                ),
                if (isPriority) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 11,
                          color: AppTheme.warning,
                        ),
                        SizedBox(width: 2),
                        Text(
                          'PRIORITY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onPrimaryAction,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  primaryActionText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
