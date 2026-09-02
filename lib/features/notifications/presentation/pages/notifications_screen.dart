import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/core/navigation/main_tab_navigation.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_dashboard_screen.dart';
import 'package:palengkego/features/recipes/application/recipe_provider.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';
import 'package:palengkego/features/recipes/presentation/pages/recipe_details_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.read only — ListenableBuilder below handles all reactivity.
    final notifService = ref.read(notificationServiceProvider);
    final user = ref.watch(authProvider);

    return ListenableBuilder(
      listenable: notifService,
      builder: (context, _) {
        final isVendor = user?.role == UserRole.vendor;
        final notifications = isVendor
            ? notifService.forVendor
            : notifService.forCustomer;
        final unreadCount = isVendor
            ? notifService.vendorUnreadCount
            : notifService.customerUnreadCount;
        return Scaffold(
          backgroundColor: AppTheme.surface,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
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
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 18,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Flexible(
                                child: Text(
                                  'Notifications',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryGreen,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (unreadCount > 0)
                          GestureDetector(
                            onTap: () => notifService.markAllRead(
                              isVendor
                                  ? NotificationTarget.vendor
                                  : NotificationTarget.customer,
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

                // Sticky status banner
                SliverPersistentHeader(
                  pinned: true,
                  floating: false,
                  delegate: _StatusBannerDelegate(unreadCount: unreadCount),
                ),

                // Notification list
                if (notifications.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyNotifications(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final notif = notifications[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _NotificationCard(
                            notification: notif,
                            onTap: () async {
                              notifService.markRead(notif.id);
                              if (notif.type == NotificationType.recipe) {
                                navigateToMainTab(context, 3);
                              } else if (notif.id.startsWith(
                                'vendor_reg_success',
                              )) {
                                final entered = await ref
                                    .read(authProvider.notifier)
                                    .enterVendorMode();
                                if (!entered) {
                                  if (context.mounted) {
                                    AppServices.showError(
                                      'Only stall holders can manage a stall.',
                                    );
                                  }
                                  return;
                                }
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    PageTransitions.slideFromRight(
                                      const VendorDashboardScreen(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              }
                            },
                          ),
                        );
                      }, childCount: notifications.length),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 32,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

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
              Icons.notifications_none_rounded,
              color: AppTheme.primaryGreen,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "You're all caught up!",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'New order updates will appear here.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification card
// ---------------------------------------------------------------------------
// Notification card
// ---------------------------------------------------------------------------
class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = _typeConfig(notification.type);
    final isRead = notification.isRead;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          // Unread: very light brand-tinted bg. Read: plain white.
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
                color: config.bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(config.icon, size: 20, color: config.iconColor),
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
                            // Unread: heavy. Read: medium — weight carries the state.
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
                          decoration: const BoxDecoration(
                            color: Color(0xFFF59E0B),
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
                  if (notification.type == NotificationType.recipe)
                    _buildRecipeCards(context, ref),
                  const SizedBox(height: 8),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCards(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(recipeRepositoryProvider);
    final allRecipesFuture = repository.getRecipes();

    return FutureBuilder<List<Recipe>>(
      future: allRecipesFuture,
      builder: (context, snapshot) {
        final allRecipes = snapshot.data ?? const <Recipe>[];

        // Find the suggested recipe in the body if any
        Recipe? suggested;
        for (final r in allRecipes) {
          if (notification.body.toLowerCase().contains(r.title.toLowerCase())) {
            suggested = r;
            break;
          }
        }

        // Put suggested recipe first, followed by others
        final list = <Recipe>[];
        if (suggested != null) {
          list.add(suggested);
          list.addAll(allRecipes.where((r) => r.title != suggested!.title));
        } else {
          list.addAll(allRecipes);
        }

        return Container(
          height: 90,
          margin: const EdgeInsets.only(top: 10, bottom: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            itemBuilder: (context, idx) {
              final recipe = list[idx];
              final isSuggested =
                  suggested != null && recipe.title == suggested.title;
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    PageTransitions.slideFromRight(
                      RecipeDetailsScreen(recipe: recipe),
                    ),
                  );
                },
                child: Container(
                  width: 220,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSuggested ? const Color(0xFFF0FDF4) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSuggested
                          ? const Color(0xFF86EFAC)
                          : AppTheme.border,
                      width: isSuggested ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Recipe Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AdaptiveImage(
                          recipe.imageUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            width: 70,
                            height: 70,
                            color: const Color(0xFFCBD5E1),
                            child: const Icon(
                              Icons.restaurant,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Recipe Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSuggested)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                margin: const EdgeInsets.only(bottom: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'RECOMMENDED',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            Text(
                              recipe.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${recipe.time} • ${recipe.difficulty}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
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
        );
      },
    );
  }

  ({IconData icon, Color iconColor, Color bgColor}) _typeConfig(
    NotificationType type,
  ) {
    return switch (type) {
      NotificationType.order => (
        icon: Icons.shopping_bag_outlined,
        iconColor: Colors.white,
        bgColor: AppTheme.primaryGreen,
      ),
      NotificationType.promo => (
        icon: Icons.local_offer_outlined,
        iconColor: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
      ),
      NotificationType.review => (
        icon: Icons.star_outline_rounded,
        iconColor: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFEF3C7),
      ),
      NotificationType.stock => (
        icon: Icons.inbox_outlined,
        iconColor: const Color(0xFFEF4444),
        bgColor: const Color(0xFFFEF2F2),
      ),
      NotificationType.admin => (
        icon: Icons.campaign_outlined,
        iconColor: const Color(0xFF3B82F6),
        bgColor: const Color(0xFFEFF6FF),
      ),
      NotificationType.recipe => (
        icon: Icons.restaurant_menu_rounded,
        iconColor: const Color(0xFFEA580C),
        bgColor: const Color(0xFFFFF7ED),
      ),
      NotificationType.refund => (
        icon: Icons.request_quote_rounded,
        iconColor: const Color(0xFFB45309),
        bgColor: const Color(0xFFFFF7ED),
      ),
    };
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
// Sticky status banner (unchanged visual logic, now data-driven)
// ---------------------------------------------------------------------------
class _StatusBannerDelegate extends SliverPersistentHeaderDelegate {
  final int unreadCount;
  _StatusBannerDelegate({required this.unreadCount});

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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isAllCaughtUp ? 'STATUS UPDATE' : 'NEW NOTIFICATIONS',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xB2FFFFFF),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAllCaughtUp
                            ? "You're all caught up!"
                            : '$unreadCount new updates today',
                        style: const TextStyle(
                          fontSize: 16,
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
  bool shouldRebuild(covariant _StatusBannerDelegate oldDelegate) {
    return oldDelegate.unreadCount != unreadCount;
  }
}
