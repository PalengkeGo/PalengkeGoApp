import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/orders/application/external_order_overlay.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
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

import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/features/auth/application/has_vendor_stall_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palengkego/core/navigation/main_tab_navigation.dart';
export 'package:palengkego/core/navigation/main_tab_navigation.dart';

class MainScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  NotificationService? _notificationService;
  int _activeOrderCount = 0;
  bool _overlayPromptStarted = false;

  List<MarketOrder> _activeOrders(List<MarketOrder> orders) => orders
      .where(
        (order) =>
            order.status != OrderStatus.completed &&
            order.status != OrderStatus.cancelled &&
            order.status != OrderStatus.rejected,
      )
      .toList();

  int _countActiveOrders(List<MarketOrder> orders) =>
      _activeOrders(orders).length;

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
    WidgetsBinding.instance.addObserver(this);
    ExternalOrderOverlay.setOpenHandler(_openActiveOrdersFromOverlay);
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptOverlayPermission();
    });

    mainTabNotifier.addListener(_handleTabChange);
    _notificationService = ref.read(notificationServiceProvider);
    _notificationService?.addListener(_onNotificationChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkKycApprovalStatus();
    });
  }

  Future<void> _checkKycApprovalStatus() async {
    final user = ref.read(authProvider);
    if (user == null) return;
    if (user.isVendor) {
      await ref.read(hasVendorStallProvider.notifier).setHasVendorStall(true);
    }
    try {
      final client = ref.read(supabaseClientProvider);
      if (client != null) {
        final stall = await client
            .from('stall_holders')
            .select('is_kyc_approved, kyc_status')
            .or('user_id.eq.${user.uid},stall_holder_id.eq.${user.uid}')
            .maybeSingle();

        if (stall != null &&
            (stall['is_kyc_approved'] == true ||
                stall['kyc_status'] == 'approved')) {
          await ref
              .read(hasVendorStallProvider.notifier)
              .setHasVendorStall(true);
          await ref.read(authProvider.notifier).reloadUser();

          final prefs = await SharedPreferences.getInstance();
          final alreadyShown =
              prefs.getBool('kyc_approved_dialog_${user.uid}') ?? false;
          if (!alreadyShown && mounted) {
            await prefs.setBool('kyc_approved_dialog_${user.uid}', true);
            ref
                .read(notificationServiceProvider)
                .addNotification(
                  AppNotification(
                    id: 'kyc_approved_${DateTime.now().millisecondsSinceEpoch}',
                    type: NotificationType.admin,
                    target: NotificationTarget.both,
                    title: 'Application Accepted by MEPO! 🎉',
                    body:
                        'Congratulations! Your stall holder application has been accepted by MEPO.',
                    createdAt: DateTime.now(),
                  ),
                );
            ref
                .read(notificationServiceProvider)
                .showLocalNotification(
                  id: 'kyc_approved_${user.uid}'.hashCode,
                  title: 'Application Accepted by MEPO! 🎉',
                  body:
                      'Congratulations! Your stall holder application has been accepted by MEPO.',
                );
            ref.read(showKycSuccessDialogProvider.notifier).show();
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking KYC status in MainScreen: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ExternalOrderOverlay.setOpenHandler(null);
    mainTabNotifier.removeListener(_handleTabChange);
    _notificationService?.removeListener(_onNotificationChanged);
    ExternalOrderOverlay.hide();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _syncExternalOrderOverlay();
    } else {
      ExternalOrderOverlay.hide();
    }
  }

  Future<void> _maybePromptOverlayPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        _overlayPromptStarted ||
        !mounted) {
      return;
    }
    _overlayPromptStarted = true;
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool('external_order_overlay_prompted') == true ||
        await ExternalOrderOverlay.canDrawOverlays()) {
      await preferences.setBool('external_order_overlay_prompted', true);
      return;
    }

    await preferences.setBool('external_order_overlay_prompted', true);
    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keep track of active orders'),
        content: const Text(
          'Allow PalengkeGo to show a small movable order bubble over other apps. You can change this access later in Android Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (enable == true) await ExternalOrderOverlay.requestPermission();
  }

  void _syncExternalOrderOverlay() {
    if (_activeOrderCount > 0) {
      ExternalOrderOverlay.show(_activeOrderCount);
    } else {
      ExternalOrderOverlay.hide();
    }
  }

  Future<void> _openActiveOrdersFromOverlay() async {
    if (!mounted) return;
    final orders = ref.read(orderServiceProvider).value ?? const [];
    await showActiveOrdersTray(context, _activeOrders(orders));
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
    final currentOrders = ref.watch(orderServiceProvider).value ?? const [];
    _activeOrderCount = _countActiveOrders(currentOrders);
    ref.listen(orderServiceProvider, (previous, next) {
      final orders = next.value ?? const [];
      _activeOrderCount = _countActiveOrders(orders);
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.hidden) {
        _syncExternalOrderOverlay();
      }
    });
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

    return ValueListenableBuilder<int>(
      valueListenable: mainTabNotifier,
      builder: (context, selectedIndex, _) {
        // Clamp to valid range — mainTabNotifier may retain stale value (e.g. 4)
        // from before cart was removed from tabs, especially on hot reload
        // Clamp to valid range (0-3: Home, Market, Orders, Recipes)
        final safeIndex = selectedIndex.clamp(0, _pages.length - 1);
        return Scaffold(
          extendBody: true,
          body: Stack(
            fit: StackFit.expand,
            children: [_pages[safeIndex], const FloatingOrderProgress()],
          ),
          bottomNavigationBar: Consumer(
            builder: (context, ref, _) {
              final notif = ref.watch(notificationServiceProvider);
              final cartVal = ref.watch(cartCountProvider).value ?? 0;
              final recipeUnreadCount = notif.forCustomer
                  .where((n) => n.type == NotificationType.recipe && !n.isRead)
                  .length;
              return AppBottomNavBar(
                selectedIndex: safeIndex,
                onTap: _onItemTapped,
                cartBadgeCount: cartVal > 0 ? cartVal : null,
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
