import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';

/// Lowercased product names from orders the customer actually bought (any
/// non-cancelled / non-rejected order — a paid purchase counts even before the
/// order is fulfilled). This matches the purchase gate used across the recipes
/// feature so a completed purchase unlocks recipes right away.
Set<String> purchasedProductNamesFrom(List<MarketOrder> orders) {
  return orders
      .where((order) =>
          order.status != OrderStatus.cancelled &&
          order.status != OrderStatus.rejected)
      .expand((order) => order.items)
      .map((item) => item.productName.toLowerCase())
      .toSet();
}

/// Recipes whose title or ingredients match any purchased item.
List<Recipe> unlockedRecipes(List<Recipe> allRecipes, Set<String> purchased) {
  return allRecipes.where((recipe) {
    final titleLower = recipe.title.toLowerCase();
    if (purchased.any(
      (p) => titleLower.contains(p) || p.contains(titleLower),
    )) {
      return true;
    }
    if (recipe.ingredients != null) {
      for (final ing in recipe.ingredients!) {
        final ingName = ing.name.toLowerCase();
        if (purchased.any((p) => ingName.contains(p) || p.contains(ingName))) {
          return true;
        }
      }
    }
    return false;
  }).toList();
}
