import 'package:flutter/material.dart';
import 'package:palengkego/core/theme/app_theme.dart';

/// Floating pill bottom navigation bar for the vendor dashboard,
/// crafted with double-bezel glassmorphism, concentric active indicators,
/// and tactile micro-press physics.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final pillBg = isDark
        ? const Color(0xFF1E293B)
        : Colors.white;
    final outerRing = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final activePillBg = isDark
        ? AppTheme.primaryGreen.withValues(alpha: 0.22)
        : AppTheme.primaryGreen.withValues(alpha: 0.12);
    final activePillBorder = isDark
        ? AppTheme.primaryGreen.withValues(alpha: 0.35)
        : AppTheme.primaryGreen.withValues(alpha: 0.22);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 350;
        final horizontalMargin = compact ? 12.0 : 16.0;
        final activeFontSize = compact ? 8.0 : 8.5;
        final inactiveFontSize = compact ? 7.5 : 8.0;
        final iconSize = compact ? 17.0 : 18.5;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalMargin,
              0,
              horizontalMargin,
              bottomInset > 0 ? 4 : 8,
            ),
            child: Center(
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: outerRing, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                        blurRadius: 18,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 4,
                        spreadRadius: 0,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: _VendorPillNavItem(
                          index: 0,
                          selectedIndex: selectedIndex,
                          onTap: onSelect,
                          label: 'Dashboard',
                          iconFilled: Icons.dashboard_rounded,
                          iconOutlined: Icons.dashboard_outlined,
                          iconSize: iconSize,
                          activeFontSize: activeFontSize,
                          inactiveFontSize: inactiveFontSize,
                          activePillBg: activePillBg,
                          activePillBorder: activePillBorder,
                        ),
                      ),
                      Expanded(
                        child: _VendorPillNavItem(
                          index: 1,
                          selectedIndex: selectedIndex,
                          onTap: onSelect,
                          label: 'Orders',
                          iconFilled: Icons.receipt_long_rounded,
                          iconOutlined: Icons.receipt_long_outlined,
                          iconSize: iconSize,
                          activeFontSize: activeFontSize,
                          inactiveFontSize: inactiveFontSize,
                          activePillBg: activePillBg,
                          activePillBorder: activePillBorder,
                        ),
                      ),
                      Expanded(
                        child: _VendorPillNavItem(
                          index: 2,
                          selectedIndex: selectedIndex,
                          onTap: onSelect,
                          label: 'Products',
                          iconFilled: Icons.inventory_2_rounded,
                          iconOutlined: Icons.inventory_2_outlined,
                          iconSize: iconSize,
                          activeFontSize: activeFontSize,
                          inactiveFontSize: inactiveFontSize,
                          activePillBg: activePillBg,
                          activePillBorder: activePillBorder,
                        ),
                      ),
                      Expanded(
                        child: _VendorPillNavItem(
                          index: 3,
                          selectedIndex: selectedIndex,
                          onTap: onSelect,
                          label: 'Profile',
                          iconFilled: Icons.person_rounded,
                          iconOutlined: Icons.person_outline_rounded,
                          iconSize: iconSize,
                          activeFontSize: activeFontSize,
                          inactiveFontSize: inactiveFontSize,
                          activePillBg: activePillBg,
                          activePillBorder: activePillBorder,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VendorPillNavItem extends StatefulWidget {
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final String label;
  final IconData iconFilled;
  final IconData iconOutlined;
  final double iconSize;
  final double activeFontSize;
  final double inactiveFontSize;
  final Color activePillBg;
  final Color activePillBorder;

  const _VendorPillNavItem({
    required this.index,
    required this.selectedIndex,
    required this.onTap,
    required this.label,
    required this.iconFilled,
    required this.iconOutlined,
    required this.iconSize,
    required this.activeFontSize,
    required this.inactiveFontSize,
    required this.activePillBg,
    required this.activePillBorder,
  });

  @override
  State<_VendorPillNavItem> createState() => _VendorPillNavItemState();
}

class _VendorPillNavItemState extends State<_VendorPillNavItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selectedIndex == widget.index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => widget.onTap(widget.index),
      child: AnimatedScale(
        scale: _isPressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected ? widget.activePillBg : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? widget.activePillBorder : Colors.transparent,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(
                isSelected ? widget.iconFilled : widget.iconOutlined,
                size: widget.iconSize,
                color: isSelected ? AppTheme.primaryGreen : const Color(0xFF64748B),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: isSelected
                      ? widget.activeFontSize
                      : widget.inactiveFontSize,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : const Color(0xFF64748B),
                  letterSpacing: 0.15,
                ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
