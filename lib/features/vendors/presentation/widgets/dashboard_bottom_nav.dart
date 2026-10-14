import 'package:flutter/material.dart';

/// Floating pill bottom navigation bar for the vendor dashboard.
/// Features high legibility typography, enlarged touch targets,
/// and a smooth sliding emerald gradient highlight that glides horizontally
/// between active tabs instead of popping in place.
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

    // Lush Emerald Gradient for the sliding active indicator
    final activeGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? const [
              Color(0xFF042018),
              Color(0xFF064E3B),
            ]
          : const [
              Color(0xFF063A2F),
              Color(0xFF076653),
            ],
    );

    // High contrast inactive text/icon color
    final inactiveColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF52605B);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 360;
    final horizontalMargin = compact ? 12.0 : 16.0;
    final activeFontSize = compact ? 10.0 : 11.0;
    final inactiveFontSize = compact ? 9.5 : 10.5;
    final iconSize = compact ? 20.0 : 22.0;
    final navHeight = compact ? 62.0 : 66.0;

    return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalMargin,
              0,
              horizontalMargin,
              bottomInset > 0 ? 6 : 10,
            ),
            child: Center(
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  height: navHeight,
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: outerRing, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.10),
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
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Smooth sliding highlight indicator
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                        alignment: Alignment(
                          -1.0 +
                              (selectedIndex.clamp(0, 3) * (2.0 / 3)),
                          0.0,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: 0.25,
                          heightFactor: 1.0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: (selectedIndex >= 0 && selectedIndex < 4)
                                ? 1.0
                                : 0.0,
                            child: Container(
                              key: const Key('vendor_nav_sliding_indicator'),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                              ),
                              decoration: BoxDecoration(
                                gradient: activeGradient,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF063A2F,
                                    ).withValues(alpha: 0.28),
                                    blurRadius: 10,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color(
                                    0xFF0A7560,
                                  ).withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Interactive Tab items
                      Row(
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
                              inactiveColor: inactiveColor,
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
                              inactiveColor: inactiveColor,
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
                              inactiveColor: inactiveColor,
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
                              inactiveColor: inactiveColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
  final Color inactiveColor;

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
    required this.inactiveColor,
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
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? widget.iconFilled : widget.iconOutlined,
                  key: ValueKey(isSelected),
                  size: widget.iconSize,
                  color: isSelected ? Colors.white : widget.inactiveColor,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: isSelected
                      ? widget.activeFontSize
                      : widget.inactiveFontSize,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : widget.inactiveColor,
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
