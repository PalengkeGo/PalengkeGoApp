import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_details_timeline.dart';

class OrderDetailsStatusCard extends StatelessWidget {
  final MarketOrder order;
  final String statusDescription;

  const OrderDetailsStatusCard({
    super.key,
    required this.order,
    required this.statusDescription,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusDescription,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 12, color: Color(0xFF9A3412)),
                      SizedBox(width: 4),
                      Text(
                        'PRIORITY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OrderDetailsTimeline(
              currentStatus: order.status,
              isPickup: order.isPickup,
            ),
          ],
        ),
      ),
    );
  }
}

class OrderDetailsArrivalCard extends StatelessWidget {
  final MarketOrder order;

  const OrderDetailsArrivalCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isCancelled =
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.rejected;
    final isCompleted = order.status == OrderStatus.completed;

    final Color iconBg = isCancelled
        ? const Color(0xFFFEF2F2)
        : (isCompleted
              ? AppTheme.surfaceContainerLow
              : const Color(0xFFECFDF5));
    final Color iconColor = isCancelled
        ? const Color(0xFFEF4444)
        : (isCompleted ? AppTheme.textSecondary : const Color(0xFF059669));
    final IconData iconData = isCancelled
        ? Icons.cancel_outlined
        : (isCompleted
              ? Icons.check_circle_outline_rounded
              : (order.isPickup
                    ? Icons.storefront_outlined
                    : Icons.local_shipping_outlined));

    String arrivalText;
    if (isCancelled) {
      arrivalText = 'Order Cancelled';
    } else if (isCompleted) {
      arrivalText = 'Order Completed';
    } else if (order.estimatedReadyTime != null) {
      arrivalText = order.isPickup
          ? 'Ready at ${DateFormat('h:mm a').format(order.estimatedReadyTime!)}'
          : 'Arriving at ${DateFormat('h:mm a').format(order.estimatedReadyTime!)}';
    } else if (order.status == OrderStatus.pending) {
      arrivalText = 'Waiting for stall holder confirmation';
    } else {
      arrivalText = 'Waiting for stall holder to set prep time';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.isPickup ? 'ESTIMATED READY TIME' : 'ESTIMATED ARRIVAL',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.muted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  arrivalText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isCancelled
                        ? const Color(0xFFEF4444)
                        : AppTheme.textPrimary,
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

class OrderDetailsAddressCard extends StatelessWidget {
  final MarketOrder order;

  const OrderDetailsAddressCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.isPickup ? 'PICKUP LOCATION' : 'DELIVERY ADDRESS',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.deliveryAddress ??
                (order.isPickup
                    ? 'Stall Holder Stall at Wet Market Section, Pasig Mega Market'
                    : 'Address not provided'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4B5563),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class OrderDetailsVendorCard extends StatelessWidget {
  final MarketOrder order;

  const OrderDetailsVendorCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'VENDOR STALL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AdaptiveImage(
                    order.vendorImage.isNotEmpty ? order.vendorImage : null,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      width: 48,
                      height: 48,
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(
                        Icons.store,
                        size: 24,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.vendorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Stall #8-14, Wet Market Section',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Calling stall holder dialer coming soon!',
                        style: TextStyle(),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.phone, size: 16),
                label: const Text('Call Stall Holder'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderDetailsPaymentCard extends StatelessWidget {
  final MarketOrder order;

  const OrderDetailsPaymentCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAYMENT METHOD',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Cash on Delivery',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

class OrderDetailsNotesCard extends StatelessWidget {
  final MarketOrder order;

  const OrderDetailsNotesCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final hasNotes = order.notes != null && order.notes!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ORDER NOTES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.note_alt_outlined,
                  size: 18,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasNotes
                        ? order.notes!
                        : 'No special instructions provided.',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasNotes
                          ? AppTheme.textPrimary
                          : AppTheme.muted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
