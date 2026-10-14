import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Compact floating pill navigation bar.
/// Features a solid, opaque pill container with a smoothly sliding emerald highlight
/// indicator that glides horizontally between active tabs instead of popping in place.
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

    // Inactive text/icon color for high contrast & legibility
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
                              (selectedIndex.clamp(0, 4) * (2.0 / 4)),
                          0.0,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: 0.2,
                          heightFactor: 1.0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: (selectedIndex >= 0 &&
                                    selectedIndex < 5 &&
                                    !(isCartAction && selectedIndex == 4))
                                ? 1.0
                                : 0.0,
                            child: Container(
                              key: const Key('nav_sliding_indicator'),
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
                          // Home (index 0)
                          Expanded(
                            child: _PillNavItem(
                              label: 'Home',
                              index: 0,
                              selectedIndex: selectedIndex,
                              onTap: onTap,
                              activeFontSize: activeFontSize,
                              inactiveFontSize: inactiveFontSize,
                              inactiveColor: inactiveColor,
                              builder: (isActive) => Icon(
                                isActive
                                    ? Icons.home_rounded
                                    : Icons.home_outlined,
                                color: isActive ? Colors.white : inactiveColor,
                                size: iconSize + 2,
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
                              inactiveColor: inactiveColor,
                              builder: (isActive) => _svgIcon(
                                asset: isActive
                                    ? 'market highlighted.svg'
                                    : 'market.svg',
                                color: isActive ? Colors.white : inactiveColor,
                                width: iconSize + 1,
                                height: iconSize - 1,
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
                              inactiveColor: inactiveColor,
                              builder: (isActive) => _svgIcon(
                                asset: 'orders.svg',
                                color: isActive ? Colors.white : inactiveColor,
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
                              inactiveColor: inactiveColor,
                              builder: (isActive) => _svgIcon(
                                asset: 'recipes.svg',
                                color: isActive ? Colors.white : inactiveColor,
                                width: iconSize + 2,
                                height: iconSize - 1,
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
                              inactiveColor: inactiveColor,
                              builder: (isActive) => _svgIcon(
                                asset: 'shopping cart icon.svg',
                                color: isActive ? Colors.white : inactiveColor,
                                width: iconSize + 1,
                                height: iconSize + 1,
                              ),
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
  final Color inactiveColor;
  final Widget Function(bool isActive) builder;

  const _PillNavItem({
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
    required this.builder,
    required this.activeFontSize,
    required this.inactiveFontSize,
    required this.inactiveColor,
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
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(isActive),
                      child: widget.builder(isActive),
                    ),
                  ),
                  if (widget.badgeCount != null && widget.badgeCount! > 0)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                              blurRadius: 4,
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
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: isActive
                      ? widget.activeFontSize
                      : widget.inactiveFontSize,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? Colors.white : widget.inactiveColor,
                  letterSpacing: 0.1,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
