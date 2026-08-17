import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';

/// A recipe the current cart can already cook, with a per-ingredient
/// breakdown of what is covered and what is still missing.
class RecipeCartMatch {
  final Recipe recipe;
  final int matchedCount;
  final int totalCount;
  final List<String> missing;

  const RecipeCartMatch({
    required this.recipe,
    required this.matchedCount,
    required this.totalCount,
    required this.missing,
  });

  bool get allInCart => missing.isEmpty;
}

/// Recipes whose ingredients appear in the user's cart, most-complete first.
///
/// Matching semantics mirror [unlockedRecipes] in `recipe_unlock.dart`:
/// lowercased, whitespace-trimmed substring matching in both directions,
/// so "Bangus (Milkfish)" in a recipe matches "Fresh Bangus" in the cart.
List<RecipeCartMatch> cartMatchesRecipes(
  List<Recipe> recipes,
  List<CartItem> cartItems,
) {
  if (cartItems.isEmpty) return const [];

  final cartNames = cartItems
      .map((item) => item.productName.toLowerCase().trim())
      .toSet();

  final matches = <RecipeCartMatch>[];
  for (final recipe in recipes) {
    final ingredients = recipe.ingredients;
    if (ingredients == null || ingredients.isEmpty) continue;

    final missing = <String>[];
    var matched = 0;
    for (final ingredient in ingredients) {
      final ingName = ingredient.name.toLowerCase().trim();
      final found = cartNames.any(
        (product) => ingName.contains(product) || product.contains(ingName),
      );
      if (found) {
        matched++;
      } else {
        missing.add(ingredient.name);
      }
    }

    if (matched == 0) continue;

    matches.add(
      RecipeCartMatch(
        recipe: recipe,
        matchedCount: matched,
        totalCount: ingredients.length,
        missing: missing,
      ),
    );
  }

  matches.sort((a, b) {
    final byCount = b.matchedCount.compareTo(a.matchedCount);
    if (byCount != 0) return byCount;
    return a.recipe.title.compareTo(b.recipe.title);
  });

  return matches;
}