import 'package:palengkego/core/theme/app_theme.dart';
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
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.amber.shade100,
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              child: Text('DEBUG stall=${stall.name} id=${stall.stallId} idx=$_selectedIndex', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(child: screens[_selectedIndex]),
                  FloatingNewOrderNotification(onViewOrders: () => setState(() => _selectedIndex = 1)),
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
