import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/features/notifications/presentation/pages/notifications_screen.dart';
import 'package:palengkego/features/profile/application/profile_provider.dart';
import 'package:palengkego/features/profile/presentation/pages/profile_screen.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/home/presentation/widgets/location_selection_sheet.dart';

/// Time-aware greeting for the home header:
/// morning 5:00-11:59, afternoon 12:00-17:59, evening 18:00-4:59.
String _currentGreeting() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifService = ref.read(notificationServiceProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final user = ref.watch(authProvider);
    final prefs = ref.watch(preferencesProvider);

    final profile = profileAsync.asData?.value;
    final userName = _getUserDisplayName(user, profile?.displayName);
    final locationText = _getLocationDisplayText(prefs.deliveryAddress);

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          // Profile Avatar
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                PageTransitions.slideFromRight(const ProfileScreen()),
              );
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: profileAsync.when(
                  data: (p) => p?.avatarUrl != null && p!.avatarUrl!.isNotEmpty
                      ? AdaptiveImage(
                          p.avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: Colors.white,
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppTheme.primaryGreen,
                              size: 26,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.white,
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppTheme.primaryGreen,
                            size: 26,
                          ),
                        ),
                  loading: () => Container(
                    color: Colors.white,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, _) => Container(
                    color: Colors.white,
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppTheme.primaryGreen,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // User Greeting and Location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName != null ? 'Hi, $userName' : _currentGreeting(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const LocationSelectionSheet(),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          locationText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Notification Button
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                PageTransitions.slideFromRight(
                  const NotificationsScreen(),
                ),
              );
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
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
          ),
        ],
      ),
    );
  }

  String? _getUserDisplayName(AppUser? user, String? profileFullName) {
    if (user == null) return null;
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    if (profileFullName != null && profileFullName.trim().isNotEmpty) {
      return profileFullName.trim();
    }
    if (user.email.isNotEmpty) {
      final emailPrefix = user.email.split('@').first;
      if (emailPrefix.isNotEmpty) return emailPrefix;
    }
    return null;
  }

  String _getLocationDisplayText(dynamic address) {
    if (address == null) return 'La Paz Public Market';
    final street = (address.streetAddress as String?)?.trim() ?? '';
    if (street.isNotEmpty) return street;
    final full = (address.fullAddress as String?)?.trim() ?? '';
    if (full.isNotEmpty) return full;
    return 'La Paz Public Market';
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
