import 'package:flutter/material.dart';
import 'package:palengkego/core/navigation/app_routes.dart';

/// Shared tab state so pushed detail pages can switch tabs and return cleanly.
/// Tabs: 0=Home, 1=Market, 2=Orders, 3=Recipes
final mainTabNotifier = ValueNotifier<int>(0);

void navigateToMainTab(BuildContext context, int index) {
  // Cart is no longer a tab - push cart screen as standalone route
  if (index == 4) {
    Navigator.of(context).pushNamed(AppRoutes.cart);
    return;
  }

  // Clamp to valid tab range (0-3)
  mainTabNotifier.value = index.clamp(0, 3);

  if (Navigator.of(context).canPop()) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    return;
  }

  Navigator.of(context).pushNamedAndRemoveUntil(
    AppRoutes.main,
    (route) => false,
    arguments: MainRouteArgs(initialIndex: index),
  );
}
