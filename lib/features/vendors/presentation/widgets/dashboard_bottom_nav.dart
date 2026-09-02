import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Bottom navigation bar for the vendor dashboard.
class VendorDashboardBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const VendorDashboardBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: _buildNavItem(
                0,
                Icons.dashboard_outlined,
                Icons.dashboard,
                'Dashboard',
              ),
            ),
            Expanded(
              child: _buildNavItem(
                1,
                Icons.receipt_outlined,
                Icons.receipt,
                'Orders',
              ),
            ),
            Expanded(
              child: _buildNavItem(
                2,
                Icons.inventory_2_outlined,
                Icons.inventory_2,
                'Products',
              ),
            ),
            Expanded(
              child: _buildNavItem(
                3,
                Icons.person_outline,
                Icons.person,
                'Profile',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData iconOutlined,
    IconData iconFilled,
    String label,
  ) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(index),
      child: Container(
        width: double.infinity,
        color: Colors.transparent,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? iconFilled : iconOutlined,
              size: 24,
              color: isSelected ? AppTheme.primaryGreen : AppTheme.muted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.primaryGreen : AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
