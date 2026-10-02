import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palengkego/core/theme/app_theme.dart';

/// Compact floating pill navigation bar.
/// Features a solid, opaque pill container centered with no outer background,
/// allowing the user to see the page around it.
class AppBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final int? cartBadgeCount;
  final int? recipeBadgeCount;
  final bool isCartAction;

  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.cartBadgeCount,
    this.recipeBadgeCount,
    this.isCartAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Solid, opaque pill background (never transparent)
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
        final iconSize = compact ? 16.0 : 17.5;

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
                      // Home (index 0)
                      Expanded(
                        child: _PillNavItem(
                          label: 'Home',
                          index: 0,
                          selectedIndex: selectedIndex,
                          onTap: onTap,
                          activeFontSize: activeFontSize,
                          inactiveFontSize: inactiveFontSize,
                          activePillBg: activePillBg,
                          activePillBorder: activePillBorder,
                          builder: (isActive) => Icon(
                            isActive ? Icons.home_rounded : Icons.home_outlined,
                            color: isActive
                                ? AppTheme.primaryGreen
                                : const Color(0xFF64748B),
                            size: iconSize + 1,
                          ),
                        ),
                      ),
                      // Market (index 1)
                      Expanded(
                        child: _PillNavItem(
                          label: 'Market',
                          index: 1,
                          selectedIndex: selectedIndex,
                          onTap: onTap,
                          activeFontSize: activeFontSize,
                          inactiveFontSize: inactiveFontSize,
                          activePillBg: activePillBg,
                          activePillBorder: activePillBorder,
                          builder: (isActive) => _svgIcon(
                            asset: isActive
                                ? 'market highlighted.svg'
                                : 'market.svg',
                            color: isActive
                                ? AppTheme.primaryGreen
                                : const Color(0xFF64748B),
                            width: iconSize,
                            height: iconSize - 2,
                          ),
                        ),
                      ),
                      // Orders (index 2)
                      Expanded(
                        child: _PillNavItem(
                          label: 'Orders',
                          index: 2,
                          selectedIndex: selectedIndex,
                          onTap: onTap,
                          activeFontSize: activeFontSize,
                          inactiveFontSize: inactiveFontSize,
                          activePillBg: activePillBg,
                          activePillBorder: activePillBorder,
                          builder: (isActive) => _svgIcon(
                            asset: 'orders.svg',
                            color: isActive
                                ? AppTheme.primaryGreen
                                : const Color(0xFF64748B),
                            width: iconSize,
                            height: iconSize,
                          ),
                        ),
                      ),
                      // Recipes (index 3)
                      Expanded(
                        child: _PillNavItem(
                          label: 'Recipes',
                          index: 3,
                          selectedIndex: selectedIndex,
                          onTap: onTap,
                          badgeCount: recipeBadgeCount,
                          activeFontSize: activeFontSize,
                          inactiveFontSize: inactiveFontSize,
                          activePillBg: activePillBg,
                          activePillBorder: activePillBorder,
                          builder: (isActive) => _svgIcon(
                            asset: 'recipes.svg',
                            color: isActive
                                ? AppTheme.primaryGreen
                                : const Color(0xFF64748B),
                            width: iconSize + 2,
                            height: iconSize - 2,
                          ),
                        ),
                      ),
                      // Cart (index 4)
                      Expanded(
                        child: _PillNavItem(
                          label: 'Cart',
                          index: 4,
                          selectedIndex: isCartAction ? -1 : selectedIndex,
                          onTap: onTap,
                          badgeCount: cartBadgeCount,
                          activeFontSize: activeFontSize,
                          inactiveFontSize: inactiveFontSize,
                          activePillBg: activePillBg,
                          activePillBorder: activePillBorder,
                          builder: (isActive) => _svgIcon(
                            asset: 'shopping cart icon.svg',
                            color: isActive
                                ? AppTheme.primaryGreen
                                : const Color(0xFF64748B),
                            width: iconSize + 1,
                            height: iconSize + 1,
                          ),
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

  static Widget _svgIcon({
    required String asset,
    required Color color,
    required double width,
    required double height,
  }) {
    return SvgPicture.asset(
      'assets/icons/$asset',
      width: width,
      height: height,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

class _PillNavItem extends StatefulWidget {
  final String label;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final int? badgeCount;
  final double activeFontSize;
  final double inactiveFontSize;
  final Color activePillBg;
  final Color activePillBorder;
  final Widget Function(bool isActive) builder;

  const _PillNavItem({
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
    required this.builder,
    required this.activeFontSize,
    required this.inactiveFontSize,
    required this.activePillBg,
    required this.activePillBorder,
    this.badgeCount,
  });

  @override
  State<_PillNavItem> createState() => _PillNavItemState();
}

class _PillNavItemState extends State<_PillNavItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.selectedIndex == widget.index;

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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isActive ? widget.activePillBg : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? widget.activePillBorder : Colors.transparent,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  widget.builder(isActive),
                  if (widget.badgeCount != null && widget.badgeCount! > 0)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 14),
                        height: 14,
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.badgeCount! > 99
                              ? '99+'
                              : '${widget.badgeCount}',
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 1),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: isActive
                      ? widget.activeFontSize
                      : widget.inactiveFontSize,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? AppTheme.primaryGreen
                      : const Color(0xFF64748B),
                  letterSpacing: 0.1,
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
