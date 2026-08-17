import 'package:palengkego/core/theme/app_theme.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        final horizontalPadding = compact ? 10.0 : 18.0;
        final itemSpacing = compact ? 2.0 : 5.0;
        final activeFontSize = compact ? 10.0 : 12.0;
        final inactiveFontSize = compact ? 9.0 : 10.0;

        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              height: 76,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                14,
                horizontalPadding,
                13,
              ),
              decoration: const BoxDecoration(
                color: Color.fromRGBO(255, 255, 255, 0.95),
                border: Border(
                  top: BorderSide(color: AppTheme.surfaceContainerLow),
                ),
              ),
              child: Row(
                children: [
                  // Home (index 0)
                  Expanded(
                    child: _NavItem(
                      label: 'Home',
                      index: 0,
                      selectedIndex: selectedIndex,
                      onTap: onTap,
                      iconSpacing: itemSpacing,
                      activeFontSize: activeFontSize,
                      inactiveFontSize: inactiveFontSize,
                      builder: (isActive) => Icon(
                        Icons.home_rounded,
                        color: isActive
                            ? AppTheme.primaryGreen
                            : AppTheme.muted,
                        size: 24,
                      ),
                    ),
                  ),
                  // Market (index 1)
                  Expanded(
                    child: _NavItem(
                      label: 'Market',
                      index: 1,
                      selectedIndex: selectedIndex,
                      onTap: onTap,
                      iconSpacing: itemSpacing,
                      activeFontSize: activeFontSize,
                      inactiveFontSize: inactiveFontSize,
                      builder: (isActive) => _svgIcon(
                        asset: isActive
                            ? 'market highlighted.svg'
                            : 'market.svg',
                        color: isActive
                            ? AppTheme.primaryGreen
                            : AppTheme.muted,
                        width: 20,
                        height: 18,
                      ),
                    ),
                  ),
                  // Orders (index 2)
                  Expanded(
                    child: _NavItem(
                      label: 'Orders',
                      index: 2,
                      selectedIndex: selectedIndex,
                      onTap: onTap,
                      iconSpacing: itemSpacing,
                      activeFontSize: activeFontSize,
                      inactiveFontSize: inactiveFontSize,
                      builder: (isActive) => _svgIcon(
                        asset: 'orders.svg',
                        color: isActive
                            ? AppTheme.primaryGreen
                            : AppTheme.muted,
                        width: 22,
                        height: 22,
                      ),
                    ),
                  ),
                  // Recipes (index 3)
                  Expanded(
                    child: _NavItem(
                      label: 'Recipes',
                      index: 3,
                      selectedIndex: selectedIndex,
                      onTap: onTap,
                      badgeCount: recipeBadgeCount,
                      iconSpacing: itemSpacing,
                      activeFontSize: activeFontSize,
                      inactiveFontSize: inactiveFontSize,
                      builder: (isActive) => _svgIcon(
                        asset: 'recipes.svg',
                        color: isActive
                            ? AppTheme.primaryGreen
                            : AppTheme.muted,
                        width: 25,
                        height: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      label: 'Cart',
                      index: 4,
                      selectedIndex: isCartAction ? -1 : selectedIndex,
                      onTap: onTap,
                      badgeCount: cartBadgeCount,
                      iconSpacing: itemSpacing,
                      activeFontSize: activeFontSize,
                      inactiveFontSize: inactiveFontSize,
                      builder: (isActive) => _svgIcon(
                        asset: 'shopping cart icon.svg',
                        color: isActive
                            ? AppTheme.primaryGreen
                            : AppTheme.muted,
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                ],
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

class _NavItem extends StatelessWidget {
  final String label;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final int? badgeCount;
  final double iconSpacing;
  final double activeFontSize;
  final double inactiveFontSize;
  final Widget Function(bool isActive) builder;

  const _NavItem({
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
    required this.builder,
    this.badgeCount,
    required this.iconSpacing,
    required this.activeFontSize,
    required this.inactiveFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                builder(isActive),
                if (badgeCount != null && badgeCount! > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: iconSpacing),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isActive ? activeFontSize : inactiveFontSize,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppTheme.primaryGreen : AppTheme.muted,
                letterSpacing: 0.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
