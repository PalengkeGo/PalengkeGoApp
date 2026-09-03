import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/core/widgets/app_bottom_nav_bar.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/home/presentation/pages/home_screen.dart';
import 'package:palengkego/features/home/presentation/pages/market_screen.dart';
import 'package:palengkego/features/orders/presentation/pages/order_history_screen.dart';
import 'package:palengkego/features/orders/presentation/widgets/floating_order_progress.dart';
import 'package:palengkego/features/recipes/presentation/pages/recipes_screen.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/core/widgets/login_required_sheet.dart';
import 'package:palengkego/features/vendors/application/kyc_provider.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_dashboard_screen.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';

import 'package:palengkego/core/navigation/main_tab_navigation.dart';
export 'package:palengkego/core/navigation/main_tab_navigation.dart';

class MainScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  NotificationService? _notificationService;

  late final List<Widget> _pages = [
    HomeScreen(onMarketSelected: () => mainTabNotifier.value = 1),
    const MarketScreen(),
    const OrderHistoryScreen(),
    const RecipesScreen(),
  ];

  void _onNotificationChanged() {
    if (mainTabNotifier.value == 3) {
      final service = ref.read(notificationServiceProvider);
      // Only call markAllOfTypeRead if there are unread recipe notifications
      // to avoid infinite rebuild loops since markAllOfTypeRead calls notifyListeners.
      final hasUnread = service.forCustomer.any(
        (n) => n.type == NotificationType.recipe && !n.isRead,
      );
      if (hasUnread) {
        service.markAllOfTypeRead(NotificationType.recipe);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Clamp index to valid range after removing cart from tabs
    final clampedIndex = widget.initialIndex.clamp(0, _pages.length - 1);

    // Check if initial tab requires login
    final user = ref.read(authProvider);
    if (user == null && (clampedIndex == 2 || clampedIndex == 3)) {
      mainTabNotifier.value = 0; // fallback to home
      WidgetsBinding.instance.addPostFrameCallback((_) {
        LoginRequiredSheet.show(
          context,
          message: clampedIndex == 2
              ? 'You must be logged in to view your orders.'
              : 'You must be logged in to view recipes.',
          onSuccess: () => mainTabNotifier.value = clampedIndex,
        );
      });
    } else {
      mainTabNotifier.value = clampedIndex;
    }

    mainTabNotifier.addListener(_handleTabChange);
    _notificationService = ref.read(notificationServiceProvider);
    _notificationService?.addListener(_onNotificationChanged);
  }

  @override
  void dispose() {
    mainTabNotifier.removeListener(_handleTabChange);
    _notificationService?.removeListener(_onNotificationChanged);
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted) return;
    final index = mainTabNotifier.value;
    if (index == 3) {
      // Entering the Recipes tab dismisses its unread badge. Guarded so a
      // no-op never re-notifies (which would otherwise rebuild this screen).
      final service = ref.read(notificationServiceProvider);
      final hasUnread = service.forCustomer.any(
        (n) => n.type == NotificationType.recipe && !n.isRead,
      );
      if (hasUnread) {
        service.markAllOfTypeRead(NotificationType.recipe);
      }
    }
    final user = ref.read(authProvider);
    if (user == null && (index == 2 || index == 3)) {
      // Revert the value back to the previous safe tab (default to 0 - home)
      mainTabNotifier.removeListener(_handleTabChange);
      mainTabNotifier.value = 0; // force back to home
      mainTabNotifier.addListener(_handleTabChange);

      LoginRequiredSheet.show(
        context,
        message: index == 2
            ? 'You must be logged in to view your orders.'
            : 'You must be logged in to view recipes.',
        onSuccess: () {
          if (mounted) mainTabNotifier.value = index;
        },
      );
    }
  }

  void _onItemTapped(int index) {
    if (index == 4) {
      // Cart button pushes the cart screen as a standalone route
      Navigator.of(context).pushNamed(AppRoutes.cart);
      return;
    }
    mainTabNotifier.value = index.clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(showKycSuccessDialogProvider, (previous, next) {
      if (next) {
        ref.read(showKycSuccessDialogProvider.notifier).dismiss();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text(
                  'Application Approved!',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: const Text(
              'Congratulations! Your application has been approved by MEPO. Your stall is now active and ready for business.',
              style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogCtx).pop(); // Dismiss dialog
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
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Manage Stall',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }
    });

    final notifService = ref.watch(notificationServiceProvider);

    return ValueListenableBuilder<int>(
      valueListenable: mainTabNotifier,
      builder: (context, selectedIndex, _) {
        // Clamp to valid range — mainTabNotifier may retain stale value (e.g. 4)
        // from before cart was removed from tabs, especially on hot reload
        // Clamp to valid range (0-3: Home, Market, Orders, Recipes)
        final safeIndex = selectedIndex.clamp(0, _pages.length - 1);
        return Scaffold(
          body: Stack(
            children: [
              IndexedStack(index: safeIndex, children: _pages),
              const FloatingOrderProgress(),
            ],
          ),
          bottomNavigationBar: ListenableBuilder(
            listenable: notifService,
            builder: (context, _) {
              final recipeUnreadCount = notifService.forCustomer
                  .where((n) => n.type == NotificationType.recipe && !n.isRead)
                  .length;
              return AppBottomNavBar(
                selectedIndex: safeIndex,
                onTap: _onItemTapped,
                cartBadgeCount: (ref.watch(cartCountProvider).value ?? 0) > 0
                    ? ref.watch(cartCountProvider).value
                    : null,
                recipeBadgeCount: recipeUnreadCount > 0
                    ? recipeUnreadCount
                    : null,
                isCartAction: true,
              );
            },
          ),
        );
      },
    );
  }
}
