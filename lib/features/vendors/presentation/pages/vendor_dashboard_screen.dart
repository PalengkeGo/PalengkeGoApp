import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';
import 'package:palengkego/features/vendors/presentation/widgets/floating_new_order_notification.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_home.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_bottom_nav.dart';

import 'vendor_orders_screen.dart';
import 'vendor_products_screen.dart';
import 'vendor_account_screen.dart';

/// Vendor Dashboard Screen
/// Main screen for vendors after completing onboarding.
/// Shows earnings summary, order stats, and quick actions.
class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stall = ref.watch(vendorStallProvider);
    final selectedIndex = ref.watch(vendorDashboardTabIndexProvider);

    final screens = [
      VendorDashboardHome(
        isStallOpen: stall.isOpen,
        onToggleStallOpen: (value) {
          ref.read(vendorStallProvider.notifier).updateStall(isOpen: value);
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
      const VendorAccountScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      resizeToAvoidBottomInset: false,
      floatingActionButton: null,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            IndexedStack(index: selectedIndex, children: screens),
            if (selectedIndex == 0)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: FloatingNewOrderNotification(
                  onViewOrders: () {
                    ref.read(vendorOrdersTabIndexProvider.notifier).select(0);
                    ref.read(vendorDashboardTabIndexProvider.notifier).select(1);
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
