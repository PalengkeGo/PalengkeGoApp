import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_stall_card.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_recent_order_card.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';
import 'package:palengkego/features/vendors/application/license_renewal_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_announcement_carousel.dart';

import 'package:palengkego/features/vendors/presentation/pages/vendor_notifications_screen.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_stall_settings_screen.dart';

/// Scrollable home tab of the vendor dashboard: greeting header,
/// license status banner, stall card, and recent orders.
class VendorDashboardHome extends ConsumerWidget {
  const VendorDashboardHome({
    super.key,
    required this.isStallOpen,
    required this.onToggleStallOpen,
    required this.onViewOrders,
    required this.onStartPreparing,
  });

  final bool isStallOpen;
  final ValueChanged<bool> onToggleStallOpen;
  final VoidCallback onViewOrders;
  final VoidCallback onStartPreparing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stall = ref.watch(vendorStallProvider);
    final user = ref.watch(authProvider);
    final greetingName = user?.displayName ?? stall.name;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).push(
                      PageTransitions.slideFromRight(
                        const VendorStallSettingsScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          image: stall.avatarImage != null
                              ? DecorationImage(
                                  image: adaptiveImageProvider(stall.avatarImage!)!,
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: stall.avatarImage == null
                            ? const Icon(
                                Icons.storefront_outlined,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PalengkeGo Stall Holder',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Good morning, $greetingName!',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final notifService = ref.read(notificationServiceProvider);
                  return ListenableBuilder(
                    listenable: notifService,
                    builder: (context, _) {
                      final unread = notifService.vendorUnreadCount;
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            PageTransitions.slideFromRight(
                              const VendorNotificationsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.scaffoldBackground,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Stack(
                            children: [
                              const Center(
                                child: Icon(
                                  Icons.notifications_outlined,
                                  color: AppTheme.primaryGreen,
                                  size: 20,
                                ),
                              ),
                              if (unread > 0)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, _) {
              final licenseStatus = ref.watch(computedLicenseStatusProvider);
              if (licenseStatus == LicenseStatus.active) {
                return const SizedBox.shrink();
              }

              Color bgColor;
              Color fgColor;
              String title;
              String message;
              IconData icon;

              if (licenseStatus == LicenseStatus.expiringSoon) {
                bgColor = const Color(0xFFFFFBEB);
                fgColor = const Color(0xFFF59E0B);
                title = 'License Expiring Soon';
                message = 'Please renew your stall license before it expires.';
                icon = Icons.warning_rounded;
              } else if (licenseStatus == LicenseStatus.expired) {
                bgColor = const Color(0xFFFEF2F2);
                fgColor = const Color(0xFFEF4444);
                title = 'License Expired';
                message =
                    'Your stall license has expired. Renew immediately to avoid suspension.';
                icon = Icons.error_rounded;
              } else {
                bgColor = const Color(0xFF7F1D1D);
                fgColor = const Color(0xFFFECACA);
                title = 'License Suspended';
                message =
                    'Your stall has been suspended. Please renew your license.';
                icon = Icons.block_rounded;
              }

              return GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.vendorLicense);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: licenseStatus == LicenseStatus.suspended
                          ? bgColor
                          : AppTheme.border,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon,
                        color: licenseStatus == LicenseStatus.suspended
                            ? Colors.white
                            : fgColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: licenseStatus == LicenseStatus.suspended
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: TextStyle(
                                fontSize: 13,
                                color: licenseStatus == LicenseStatus.suspended
                                    ? fgColor
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const DashboardAnnouncementCarousel(),
          const SizedBox(height: 24),
          const Text(
            'Your Stall',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          DashboardStallCard(onToggleStallOpen: onToggleStallOpen),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Recent Orders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onViewOrders,
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, _) {
              final ordersAsync = ref.watch(vendorOrdersProvider);
              return ordersAsync.maybeWhen(
                data: (allOrders) {
                  final orders = allOrders
                      .where(
                        (o) =>
                            o.status == OrderStatus.pending ||
                            o.status == OrderStatus.preparing,
                      )
                      .take(2)
                      .toList();

                  if (orders.isEmpty) {
                    return const Text(
                      'No recent orders.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    );
                  }

                  return Column(
                    children: orders.map((order) {
                      final itemsStr = order.items
                          .map((i) => '${i.quantityLabel} ${i.productName}')
                          .join(' | ');
                      final totalStr = '₱${order.total.toStringAsFixed(2)}';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DashboardRecentOrderCard(
                          orderId: 'Order ${order.id}',
                          customer: order.customerName,
                          items: itemsStr,
                          total: totalStr,
                          time: 'Just now',
                          deliveryMode: order.isPickup
                              ? 'Pick-Up'
                              : (order.isPriority
                                    ? 'Priority Delivery'
                                    : 'Standard Delivery'),
                          isPriority: order.isPriority,
                          primaryActionText: order.status == OrderStatus.pending
                              ? 'Start Preparing'
                              : 'View Order',
                          onPrimaryAction: order.status == OrderStatus.pending
                              ? onStartPreparing
                              : onViewOrders,
                        ),
                      );
                    }).toList(),
                  );
                },
                orElse: () => const AsyncLoadingView(),
              );
            },
          ),
        ],
      ),
    );
  }
}
