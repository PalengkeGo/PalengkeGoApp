import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';
import 'package:palengkego/features/vendors/presentation/widgets/floating_new_order_notification.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_home.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_bottom_nav.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/features/vendors/presentation/widgets/vendor_warning_dialog.dart';

import 'vendor_orders_screen.dart';
import 'vendor_products_screen.dart';
import 'vendor_account_screen.dart';
import 'package:palengkego/features/messages/presentation/pages/messages_inbox_screen.dart';

/// Vendor Dashboard Screen
/// Main screen for vendors after completing onboarding.
/// Shows earnings summary, order stats, and quick actions.
class VendorDashboardScreen extends ConsumerStatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  ConsumerState<VendorDashboardScreen> createState() =>
      _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends ConsumerState<VendorDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkWarningPopup());
  }

  Future<void> _checkWarningPopup() async {
    final user = ref.read(authProvider);
    if (user == null) return;
    final notifService = ref.read(notificationServiceProvider);
    final warnings = notifService.unacknowledgedWarnings;
    if (warnings.isNotEmpty && mounted) {
      final warning = warnings.first;
      final prefs = await SharedPreferences.getInstance();
      final ackKey = 'vendor_warning_ack_${user.uid}_${warning.id}';
      if (prefs.getBool(ackKey) == true) return;
      if (!mounted) return;
      await VendorWarningDialog.show(
        context,
        warning: warning,
        onAcknowledge: () async {
          await prefs.setBool(ackKey, true);
          notifService.markRead(warning.id);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stall = ref.watch(vendorStallProvider);
    final selectedIndex = ref.watch(vendorDashboardTabIndexProvider);

    final screens = [
      VendorDashboardHome(
        isStallOpen: stall.isOpen,
        onToggleStallOpen: (value) async {
          try {
            await ref
                .read(vendorStallProvider.notifier)
                .updateStall(isOpen: value);
          } catch (_) {
            AppServices.showError(
              'Could not save stall availability. Please try again.',
            );
            return;
          }
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value
                    ? 'Your stall is now open for orders.'
                    : 'Your stall is now marked closed.',
              ),
            ),
          );
        },
        onViewOrders: () {
          ref.read(vendorOrdersTabIndexProvider.notifier).select(0);
          ref.read(vendorDashboardTabIndexProvider.notifier).select(1);
        },
        onStartPreparing: () {
          ref.read(vendorOrdersTabIndexProvider.notifier).select(0);
          ref.read(vendorDashboardTabIndexProvider.notifier).select(1);
        },
      ),
      const VendorOrdersScreen(),
      const VendorProductsScreen(),
      const MessagesInboxScreen(isEmbeddedInTab: true),
      const VendorAccountScreen(),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: AppTheme.surface,
      resizeToAvoidBottomInset: false,
      floatingActionButton: null,
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            screens[selectedIndex],
            if (selectedIndex == 0)
              Positioned(
                bottom: 84 + MediaQuery.paddingOf(context).bottom,
                left: 16,
                right: 16,
                child: FloatingNewOrderNotification(
                  onViewOrders: () {
                    ref.read(vendorOrdersTabIndexProvider.notifier).select(0);
                    ref
                        .read(vendorDashboardTabIndexProvider.notifier)
                        .select(1);
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: VendorDashboardBottomNav(
        selectedIndex: selectedIndex,
        onSelect: (index) =>
            ref.read(vendorDashboardTabIndexProvider.notifier).select(index),
      ),
    );
  }
}
