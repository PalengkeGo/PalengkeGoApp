import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';
import 'package:palengkego/features/recipes/application/recipe_purchases_provider.dart'
    show isIngredientPurchased;

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
///
/// Uses [isIngredientPurchased] for token-based matching so that
/// "Silver Swan Soy Sauce 1L" correctly matches the recipe ingredient
/// "soy sauce" — without false positives like "Ice" matching "Rice".
List<Recipe> unlockedRecipes(List<Recipe> allRecipes, Set<String> purchased) {
  if (purchased.isEmpty) return const [];

  return allRecipes.where((recipe) {
    // Match recipe title against purchased product names
    if (isIngredientPurchased(recipe.title, purchased)) return true;

    // Match each ingredient against purchased product names
    if (recipe.ingredients != null) {
      for (final ing in recipe.ingredients!) {
        if (isIngredientPurchased(ing.name, purchased)) return true;
      }
    }
    return false;
  }).toList();
}

/// Ranks recipes by how many of their ingredients are already in the
/// given [purchased] set (from cart items). Returns recipes sorted
/// descending by match count, suitable for a "Suggested from cart" section.
List<Recipe> suggestedRecipesFromCart(
  List<Recipe> allRecipes,
  Set<String> purchased,
) {
  if (purchased.isEmpty) return const [];

  final scored = <(Recipe recipe, int matchCount)>[];
  for (final recipe in allRecipes) {
    final ings = recipe.ingredients;
    if (ings == null || ings.isEmpty) continue;

    var matchCount = 0;
    for (final ing in ings) {
      if (isIngredientPurchased(ing.name, purchased)) matchCount++;
    }
    if (matchCount > 0) scored.add((recipe, matchCount));
  }

  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return scored.map((e) => e.$1).toList();
}
