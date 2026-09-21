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
    // Force visible body to isolate blank-screen cause
    return Scaffold(
      backgroundColor: Colors.yellow.shade50,
      appBar: AppBar(title: Text('VENDOR DEBUG stall=${stall.name} idx=$_selectedIndex'), backgroundColor: Colors.amber),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('VENDOR DASHBOARD WORKS\nstall=${stall.name}\nidx=$_selectedIndex', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => setState(() => _selectedIndex = (_selectedIndex + 1) % 4), child: const Text('Switch tab')),
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
