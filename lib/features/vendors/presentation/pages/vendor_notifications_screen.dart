import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';

class VendorNotificationsScreen extends ConsumerWidget {
  const VendorNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.read only — ListenableBuilder below handles all reactivity.
    final notifService = ref.read(notificationServiceProvider);

    return AuthGuard(
      allowedRoles: {UserRole.vendor},
      child: ListenableBuilder(
        listenable: notifService,
        builder: (context, _) {
          final notifications = notifService.forVendor;
          final unreadCount = notifService.vendorUnreadCount;

          return Scaffold(
            backgroundColor: AppTheme.surface,
            body: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.maybePop(context),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.surfaceContainerLow,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 16,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                          if (unreadCount > 0)
                            GestureDetector(
                              onTap: () => notifService.markAllRead(
                                NotificationTarget.vendor,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Mark all read',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Morphing sticky banner
                  SliverPersistentHeader(
                    pinned: true,
                    floating: false,
                    delegate: _VendorStatusBannerDelegate(
                      unreadCount: unreadCount,
                    ),
                  ),

                  // Notifications list
                  if (notifications.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyVendorNotifications(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final notif = notifications[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _VendorNotificationCard(
                              notification: notif,
                              onTap: () => notifService.markRead(notif.id),
                            ),
                          );
                        }, childCount: notifications.length),
                      ),
                    ),

                  // Vendor pro-tip box (always shown at bottom)
                  if (notifications.isNotEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverToBoxAdapter(child: _VendorProTip()),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyVendorNotifications extends StatelessWidget {
  const _EmptyVendorNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppTheme.primaryGreen,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'All alerts cleared!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'New order alerts will appear here.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vendor notification card
// ---------------------------------------------------------------------------
class _VendorNotificationCard extends StatelessWidget {
  const _VendorNotificationCard({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final config = _typeConfig(notification.type);
    final isRead = notification.isRead;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFC8E6D4),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(
                alpha: isRead ? 0.04 : 0.12,
              ),
              blurRadius: isRead ? 6 : 16,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: config.bg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(config.icon, color: config.accent, size: 20),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: isRead
                                ? AppTheme.textSecondary
                                : AppTheme.primaryGreen,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            color: config.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: isRead
                          ? AppTheme.muted
                          : const Color(0xFF1A5C45),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Timestamp chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isRead
                              ? const Color(0xFFF3F4F6)
                              : const Color(0xFF9DD4B5),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          _relativeTime(notification.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isRead
                                ? AppTheme.muted
                                : const Color(0xFF0B7A50),
                          ),
                        ),
                      ),
                      // Mark Read action (vendor-specific: explicit is helpful)
                      if (!isRead)
                        GestureDetector(
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: config.accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Mark read',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: config.accent,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({IconData icon, Color accent, Color bg}) _typeConfig(NotificationType type) {
    return switch (type) {
      NotificationType.order => (
        icon: Icons.shopping_bag_outlined,
        accent: const Color(0xFF059669),
        bg: const Color(0xFFF0FDF4),
      ),
      NotificationType.stock => (
        icon: Icons.inbox_outlined,
        accent: const Color(0xFFEF4444),
        bg: const Color(0xFFFEF2F2),
      ),
      NotificationType.review => (
        icon: Icons.star_outline_rounded,
        accent: const Color(0xFFF59E0B),
        bg: const Color(0xFFFEF3C7),
      ),
      NotificationType.admin => (
        icon: Icons.campaign_outlined,
        accent: const Color(0xFF3B82F6),
        bg: const Color(0xFFEFF6FF),
      ),
      NotificationType.promo => (
        icon: Icons.local_offer_outlined,
        accent: const Color(0xFF059669),
        bg: const Color(0xFFECFDF5),
      ),
      NotificationType.recipe => (
        icon: Icons.restaurant_menu_rounded,
        accent: const Color(0xFFEA580C),
        bg: const Color(0xFFFFF7ED),
      ),
      NotificationType.refund => (
        icon: Icons.request_quote_rounded,
        accent: const Color(0xFFB45309),
        bg: const Color(0xFFFFF7ED),
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Pro-tip box
// ---------------------------------------------------------------------------
class _VendorProTip extends StatelessWidget {
  const _VendorProTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFF0369A1),
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stall Holder Pro-Tip',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0369A1),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Keeping your inventory updated reduces order cancellations and builds buyer trust.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF075985),
                    height: 1.4,
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

// ---------------------------------------------------------------------------
// Relative time helper
// ---------------------------------------------------------------------------
String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${diff.inDays ~/ 7} week${diff.inDays ~/ 7 > 1 ? 's' : ''} ago';
}

// ---------------------------------------------------------------------------
// Sticky status banner delegate
// ---------------------------------------------------------------------------
class _VendorStatusBannerDelegate extends SliverPersistentHeaderDelegate {
  _VendorStatusBannerDelegate({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final horizontalPadding = 16.0 * (1.0 - progress);
    final isAllCaughtUp = unreadCount == 0;
    final bannerColor = isAllCaughtUp
        ? AppTheme.accentGreen
        : AppTheme.primaryGreen;

    return SizedBox.expand(
      child: Container(
        color: AppTheme.surface,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Container(
          height: 84.0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: bannerColor,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(
                  isAllCaughtUp ? 109 : 11,
                  isAllCaughtUp ? 151 : 55,
                  isAllCaughtUp ? 115 : 43,
                  0.3 * progress,
                ),
                blurRadius: 16 * progress,
                offset: Offset(0, 4 * progress),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAllCaughtUp
                          ? 'STALL OPERATIONAL STATUS'
                          : 'URGENT NOTIFICATIONS',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xB2FFFFFF),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAllCaughtUp
                          ? 'All alerts cleared! Nice job.'
                          : '$unreadCount critical tasks require attention',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0x26FFFFFF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAllCaughtUp
                      ? Icons.check_rounded
                      : Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 120;

  @override
  double get minExtent => 84;

  @override
  bool shouldRebuild(covariant _VendorStatusBannerDelegate oldDelegate) {
    return oldDelegate.unreadCount != unreadCount;
  }
}
