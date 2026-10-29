import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';

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
import 'package:palengkego/features/home/presentation/widgets/announcement_popup_listener.dart';
import 'package:palengkego/features/home/presentation/pages/market_screen.dart';
import 'package:palengkego/features/orders/presentation/pages/order_history_screen.dart';
import 'package:palengkego/features/orders/presentation/widgets/floating_order_progress.dart';
import 'package:palengkego/features/recipes/presentation/pages/recipes_screen.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/presentation/widgets/account_restriction_screen.dart';
import 'package:palengkego/core/widgets/login_required_sheet.dart';
import 'package:palengkego/features/vendors/application/kyc_provider.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_dashboard_screen.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';

import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palengkego/features/auth/application/has_vendor_stall_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/features/vendors/presentation/widgets/vendor_warning_dialog.dart';
import 'package:palengkego/features/vendors/presentation/widgets/kyc_status_dialogs.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_onboarding_screen.dart';
import 'package:palengkego/features/auth/presentation/widgets/email_verification_reminder_dialog.dart';

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
  Timer? _accountSyncTimer;
  RealtimeChannel? _accountRealtimeChannel;
  SupabaseClient? _accountSupabaseClient;
  StreamSubscription<RemoteMessage>? _foregroundPushSubscription;
  StreamSubscription<String>? _pushTokenSubscription;
  bool _accountSyncInProgress = false;
  bool _accountNoticeDialogOpen = false;
  final Set<String> _shownAccountNotices = {};
  int _activeOrderCount = 0;
  bool _overlayPromptStarted = false;
  bool _emailVerificationDialogOpen = false;
  bool _emailVerificationDialogPending = false;
  bool _kycApprovalCheckInProgress = false;
  bool _kycApprovalDialogPending = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybePromptOverlayPermission();
      await _maybeShowEmailVerificationReminder();
    });

    mainTabNotifier.addListener(_handleTabChange);
    _notificationService = ref.read(notificationServiceProvider);
    _notificationService?.addListener(_onNotificationChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkKycApprovalStatus();
      _startAccountSync();
      _subscribeToAccountUpdates();
      _initializeAccountPush();
    });
  }

  void _startAccountSync() {
    _accountSyncTimer?.cancel();
    unawaited(_syncAccountAndNotifications());
    // ponytail: foreground polling costs 24 small profile/notification reads
    // per minute; move to filtered Realtime subscriptions if auth permits them.
    _accountSyncTimer = Timer.periodic(
      const Duration(milliseconds: 2500),
      (_) => _syncAccountAndNotifications(),
    );
  }

  Future<void> _syncAccountAndNotifications() async {
    if (!mounted || _accountSyncInProgress) return;
    _accountSyncInProgress = true;
    try {
      final user = ref.read(authProvider);
      if (user == null || user.uid.isEmpty) return;
      await ref.read(authProvider.notifier).reloadUser();
      await _notificationService?.syncRemoteNotifications(user.uid);
      if (user.isVendor) await _checkVendorWarnings();
    } finally {
      _accountSyncInProgress = false;
    }
  }

  void _subscribeToAccountUpdates() {
    final previousChannel = _accountRealtimeChannel;
    final previousClient = _accountSupabaseClient;
    _accountRealtimeChannel = null;
    _accountSupabaseClient = null;
    if (previousChannel != null && previousClient != null) {
      unawaited(previousClient.removeChannel(previousChannel));
    }

    final client = ref.read(supabaseClientProvider);
    final user = ref.read(authProvider);
    if (client == null || user == null || user.uid.isEmpty) return;
    _accountSupabaseClient = client;
    _accountRealtimeChannel = client
        .channel('account-updates-${user.uid}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.uid,
          ),
          callback: (_) => unawaited(_syncAccountAndNotifications()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'stall_holders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.uid,
          ),
          callback: (_) {
            ref.invalidate(userKycSubmissionProvider);
            unawaited(_checkKycApprovalStatus());
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.uid,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            if (row.isEmpty) return;
            unawaited(_handleRealtimeNotification(row));
          },
        )
        .subscribe();
  }

  Future<void> _handleRealtimeNotification(Map<String, dynamic> row) async {
    final title = row['title']?.toString().trim().toLowerCase();
    if (row['type'] == 'kyc_update' && title == 'application approved') {
      unawaited(_checkKycApprovalStatus(showApprovalDialog: true));
    }
    final isAccountNotice = const {
      'account blocked',
      'account suspension',
      'account restored',
      'suspension lifted',
    }.contains(title);
    final notice = await ref
        .read(notificationServiceProvider)
        .acceptRemoteNotification(
          row,
          showDeviceNotification: !isAccountNotice,
        );
    if (notice?.type == NotificationType.warning &&
        ref.read(authProvider)?.isVendor == true) {
      await _checkVendorWarnings();
      return;
    }
    if (notice == null ||
        !const {'account blocked', 'account suspension', 'account restored', 'suspension lifted'}
            .contains(notice.title.trim().toLowerCase())) {
      return;
    }
    _showAccountNotice(notice.id, notice.title, notice.body);
  }

  void _showAccountNotice(String id, String title, String body) {
    if (!mounted || !_shownAccountNotices.add(id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _accountNoticeDialogOpen) return;
      _accountNoticeDialogOpen = true;
      try {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(
              title.toLowerCase().contains('blocked')
                  ? Icons.block_rounded
                  : Icons.warning_amber_rounded,
              color: Colors.deepOrange,
              size: 36,
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Text(
              body,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  title.trim().toLowerCase() == 'account restored'
                      ? 'Accept'
                      : 'I understand',
                ),
              ),
            ],
          ),
        );
      } finally {
        _accountNoticeDialogOpen = false;
      }
    });
  }

  Future<void> _initializeAccountPush() async {
    final messaging = ref.read(firebaseMessagingProvider);
    if (messaging == null) return;
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      await _registerAccountPushToken(await messaging.getToken());
      _pushTokenSubscription ??= messaging.onTokenRefresh.listen(
        _registerAccountPushToken,
      );
      _foregroundPushSubscription ??= FirebaseMessaging.onMessage.listen((message) {
        final title = message.notification?.title ?? message.data['title']?.toString();
        final body = message.notification?.body ?? message.data['body']?.toString();
        if (title == null || body == null) return;
        final id = message.data['notification_id']?.toString() ??
            '${title}_${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';
        unawaited(ref.read(notificationServiceProvider).showLocalNotification(
          id: id.hashCode,
          title: title,
          body: body,
          channelId: 'palengkego_account_updates',
          channelName: 'Account Updates',
        ));
        unawaited(_syncAccountAndNotifications());
        if (title.toLowerCase().contains('account') ||
            title.toLowerCase().contains('suspension')) {
          _showAccountNotice(id, title, body);
        }
      });
    } catch (error) {
      debugPrint('Could not initialize account push notifications: $error');
    }
  }

  Future<void> _registerAccountPushToken(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      final firebaseUser = ref.read(firebaseAuthProvider)?.currentUser;
      final client = ref.read(supabaseClientProvider);
      if (firebaseUser == null || client == null) return;
      final idToken = await firebaseUser.getIdToken();
      if (idToken == null) return;
      await client.functions.invoke(
        'account-device-token',
        headers: {'Authorization': 'Bearer $idToken'},
        body: {'token': token, 'platform': defaultTargetPlatform.name},
      );
    } catch (error) {
      debugPrint('Could not register account push token: $error');
    }
  }

  Future<bool> _refreshEmailVerificationStatus() async {
    final firebaseUser = ref.read(firebaseAuthProvider)?.currentUser;
    if (firebaseUser == null) return false;

    try {
      await firebaseUser.reload();
      await ref.read(authProvider.notifier).reloadUser();
      return ref.read(authProvider)?.isVerified ?? false;
    } catch (error) {
      debugPrint('Could not refresh email verification status: $error');
      return false;
    }
  }

  Future<void> _maybeShowEmailVerificationReminder() async {
    if (!mounted ||
        !ref.read(firebaseEnabledProvider) ||
        mainTabNotifier.value != 0 ||
        _emailVerificationDialogOpen ||
        _emailVerificationDialogPending) {
      return;
    }

    _emailVerificationDialogPending = true;
    try {
      await _refreshEmailVerificationStatus();
      final user = ref.read(authProvider);
      if (!mounted ||
          user == null ||
          user.isVerified ||
          user.isGoogleUser ||
          mainTabNotifier.value != 0) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final dismissedKey = 'email_verification_reminder_dismissed_${user.uid}';
      if (!mounted || prefs.getBool(dismissedKey) == true) return;

      _emailVerificationDialogOpen = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => EmailVerificationReminderDialog(
          email: user.email,
          onGotIt: () async {
            await prefs.setBool(dismissedKey, true);
          },
          onCheckVerification: _refreshEmailVerificationStatus,
        ),
      );
    } finally {
      _emailVerificationDialogOpen = false;
      _emailVerificationDialogPending = false;
    }
  }

  Future<void> _checkKycApprovalStatus({
    bool showApprovalDialog = false,
  }) async {
    if (_kycApprovalCheckInProgress) {
      _kycApprovalDialogPending =
          _kycApprovalDialogPending || showApprovalDialog;
      return;
    }
    final user = ref.read(authProvider);
    if (user == null) return;
    _kycApprovalCheckInProgress = true;
    var shouldShowApprovalDialog = showApprovalDialog;
    try {
      if (user.isVendor) {
        await ref.read(hasVendorStallProvider.notifier).setHasVendorStall(true);
      }
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

          final application = await client
              .from('kyc_submissions')
              .select('kyc_id, status')
              .eq('stall_holder_id', user.uid)
              .order('submitted_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (application == null || application['status'] != 'approved') {
            return;
          }

          shouldShowApprovalDialog =
              shouldShowApprovalDialog || _kycApprovalDialogPending;
          _kycApprovalDialogPending = false;
          if (!shouldShowApprovalDialog) return;

          final prefs = await SharedPreferences.getInstance();
          final dialogKey =
              'kyc_approved_dialog_${user.uid}_${application['kyc_id'] as String}';
          final alreadyShown = prefs.getBool(dialogKey) == true;
          if (!alreadyShown && mounted) {
            // Only a live approval event opens the dialog. Persist its KYC ID
            // before showing it so later logins do not repeat the modal.
            await prefs.setBool(dialogKey, true);
            ref.read(showKycSuccessDialogProvider.notifier).show();
          }
        } else if (stall != null && stall['kyc_status'] == 'rejected') {
          String? reason;
          String? submittedAt;
          try {
            final kyc = await client
                .from('kyc_submissions')
                .select('rejection_reason, submitted_at')
                .eq('stall_holder_id', user.uid)
                .order('submitted_at', ascending: false)
                .limit(1)
                .maybeSingle();
            reason = kyc?['rejection_reason'] as String?;
            submittedAt = kyc?['submitted_at'] as String?;
          } catch (_) {}

          final prefs = await SharedPreferences.getInstance();
          final key =
              'kyc_rejected_shown_${user.uid}_${submittedAt ?? 'latest'}';
          final alreadyShown = prefs.getBool(key) ?? false;
          if (!alreadyShown && mounted) {
            await prefs.setBool(key, true);
            if (!mounted) return;
            await KycRejectionDialog.show(
              context,
              rejectionReason: reason,
              onResubmit: () {
                if (!mounted) return;
                Navigator.of(context).push(
                  PageTransitions.slideFromRight(
                    const VendorOnboardingScreen(),
                  ),
                );
              },
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking KYC status in MainScreen: $e');
    } finally {
      _kycApprovalCheckInProgress = false;
      if (_kycApprovalDialogPending && mounted) {
        _kycApprovalDialogPending = false;
        unawaited(_checkKycApprovalStatus(showApprovalDialog: true));
      }
    }
  }

  Future<void> _checkVendorWarnings() async {
    final user = ref.read(authProvider);
    if (user == null || !user.isVendor) return;

    final service = ref.read(notificationServiceProvider);
    final unacknowledged = service.unacknowledgedWarnings;

    if (unacknowledged.isNotEmpty && mounted) {
      final warning = unacknowledged.first;
      final prefs = await SharedPreferences.getInstance();
      final ackKey = 'vendor_warning_ack_${user.uid}_${warning.id}';
      if (prefs.getBool(ackKey) == true) return;

      if (!mounted) return;
      await VendorWarningDialog.show(
        context,
        warning: warning,
        onAcknowledge: () async {
          await prefs.setBool(ackKey, true);
          service.markRead(warning.id);
        },
      );
    }
  }

  @override
  void dispose() {
    _accountSyncTimer?.cancel();
    final channel = _accountRealtimeChannel;
    final client = _accountSupabaseClient;
    if (channel != null && client != null) {
      unawaited(client.removeChannel(channel));
    }
    _foregroundPushSubscription?.cancel();
    _pushTokenSubscription?.cancel();
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
      _accountSyncTimer?.cancel();
      _syncExternalOrderOverlay();
    } else if (state == AppLifecycleState.resumed) {
      _refreshEmailVerificationStatus();
      _startAccountSync();
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
    if (index == 0) _maybeShowEmailVerificationReminder();
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
    final user = ref.watch(authProvider);
    ref.listen(authProvider, (previous, next) {
      if (previous?.uid != next?.uid) {
        _subscribeToAccountUpdates();
        _initializeAccountPush();
      }
      if (next != null && !next.isVerified && !next.isGoogleUser) {
        _maybeShowEmailVerificationReminder();
      }
    });
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
                Expanded(
                  child: Text(
                    'Application Approved!',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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

    final mainContent = ValueListenableBuilder<int>(
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
            children: [
              if (safeIndex == 0)
                AnnouncementPopupListener(child: _pages[safeIndex])
              else
                _pages[safeIndex],
              const FloatingOrderProgress(),
            ],
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
    if (user?.isBlocked == true) {
      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Opacity(opacity: 0.7, child: mainContent),
          ),
          const ModalBarrier(dismissible: false, color: Colors.transparent),
          AccountRestrictionScreen(
            user: user!,
            transparentBackground: true,
          ),
        ],
      );
    }
    if (user?.isSuspended == true) {
      return AccountRestrictionScreen(user: user!);
    }
    return mainContent;
  }
}
