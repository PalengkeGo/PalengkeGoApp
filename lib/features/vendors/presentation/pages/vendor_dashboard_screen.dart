import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/presentation/widgets/floating_new_order_notification.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_home.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_bottom_nav.dart';

import 'vendor_orders_screen.dart';
import 'vendor_products_screen.dart';
import 'vendor_account_screen.dart';

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
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final stall = ref.watch(vendorStallProvider);
    final screens = [
      VendorDashboardHome(
        isStallOpen: stall.isOpen,
        onToggleStallOpen: (value) {
          ref.read(vendorStallProvider.notifier).updateStall(isOpen: value);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(value ? 'Your stall is now open for orders.' : 'Your stall is now marked closed.')),
          );
        },
        onViewOrders: () => setState(() => _selectedIndex = 1),
        onStartPreparing: () => setState(() => _selectedIndex = 1),
      ),
      const VendorOrdersScreen(),
      const VendorProductsScreen(),
      const VendorAccountScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      floatingActionButton: _selectedIndex == 2
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.vendorAddProduct),
              backgroundColor: AppTheme.primaryGreen,
              elevation: 4,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IndexedStack(index: _selectedIndex, children: screens),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: FloatingNewOrderNotification(
                      onViewOrders: () => setState(() => _selectedIndex = 1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: VendorDashboardBottomNav(
        selectedIndex: _selectedIndex,
        onSelect: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
