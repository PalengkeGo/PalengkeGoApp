import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/features/notifications/presentation/pages/notifications_screen.dart';
import 'package:palengkego/features/profile/application/profile_provider.dart';
import 'package:palengkego/features/profile/presentation/pages/profile_screen.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/home/presentation/widgets/location_selection_sheet.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifService = ref.read(notificationServiceProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final user = ref.watch(authProvider);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => const LocationSelectionSheet(),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              AppLocalizations.of(context).homeDeliveryTo,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.accentGreen,
                                letterSpacing: 0.6,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppTheme.accentGreen,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Consumer(
                        builder: (context, ref, _) {
                          final currentAddress = ref
                              .watch(preferencesProvider)
                              .deliveryAddress;
                          return Text(
                            currentAddress.label.isEmpty
                                ? currentAddress.primaryAddress
                                : '${currentAddress.label} • ${currentAddress.primaryAddress}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                              letterSpacing: -0.6,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 84,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      PageTransitions.slideFromRight(
                        const NotificationsScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: 32,
                    height: 36,
                    alignment: Alignment.center,
                    child: ListenableBuilder(
                      listenable: notifService,
                      builder: (context, _) {
                        final unread = user?.role == UserRole.vendor
                            ? notifService.vendorUnreadCount
                            : notifService.customerUnreadCount;
                        final latestId = user?.role == UserRole.vendor
                            ? notifService.forVendor.firstOrNull?.id
                            : notifService.forCustomer.firstOrNull?.id;
                        return _ShakingNotificationIcon(
                          unreadCount: unread,
                          latestNotifId: latestId,
                        );
                      },
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      PageTransitions.slideFromRight(const ProfileScreen()),
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppTheme.scaffoldBackground,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: profileAsync.when(
                        data: (profile) => AdaptiveImage(
                          profile?.avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: const Icon(
                            Icons.person,
                            color: AppTheme.muted,
                            size: 24,
                          ),
                        ),
                        loading: () =>
                            const CircularProgressIndicator(strokeWidth: 2),
                        error: (_, _) => const Icon(
                          Icons.person,
                          color: AppTheme.muted,
                          size: 24,
                        ),
                      ),
                    ),
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

class _ShakingNotificationIcon extends StatefulWidget {
  final int unreadCount;
  final String? latestNotifId;
  const _ShakingNotificationIcon({
    required this.unreadCount,
    this.latestNotifId,
  });

  @override
  State<_ShakingNotificationIcon> createState() =>
      _ShakingNotificationIconState();
}

class _ShakingNotificationIconState extends State<_ShakingNotificationIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int _prevCount = 0;
  String? _prevLatestId;

  @override
  void initState() {
    super.initState();
    _prevCount = widget.unreadCount;
    _prevLatestId = widget.latestNotifId;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.unreadCount > 0) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _ShakingNotificationIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasNewNotif =
        widget.latestNotifId != null && widget.latestNotifId != _prevLatestId;
    if (widget.unreadCount > _prevCount || hasNewNotif) {
      _controller.forward(from: 0.0);
    }
    _prevCount = widget.unreadCount;
    _prevLatestId = widget.latestNotifId;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animation.value,
          alignment: Alignment.topCenter,
          child: child,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            widget.unreadCount > 0
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            size: 24,
            color: AppTheme.primaryGreen,
          ),
          if (widget.unreadCount > 0)
            Positioned(
              top: -2,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 14),
                height: 14,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.unreadCount}',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
