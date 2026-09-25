import 'package:palengkego/core/utils/ingredient_noise_words.dart';
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
      .map((item) => item.productName.toLowerCase().trim())
      .where((name) => name.isNotEmpty)
      .toSet();
}

/// Derivative terms that indicate a compound product or non-fruit/non-produce item.
/// For example, buying "banana" fruit should not match "banana ketchup", "banana heart",
/// or "banana leaves".
const compoundDerivativeExclusions = <String, Set<String>>{
  'banana': {
    'ketchup',
    'catsup',
    'heart',
    'blossom',
    'puso',
    'leaf',
    'leaves',
    'dahon',
    'essence',
    'extract',
    'flavor',
    'flavoring',
  },
  'fish': {'sauce', 'patis', 'paste', 'cracker', 'crackers'},
  'shrimp': {'paste', 'bagoong', 'cube', 'cubes', 'bouillon', 'cracker', 'crackers'},
  'hipon': {'paste', 'bagoong', 'cube', 'cubes'},
  'oyster': {'sauce'},
  'chicken': {'cube', 'cubes', 'powder', 'bouillon'},
  'pork': {'cube', 'cubes', 'powder', 'bouillon'},
  'beef': {'cube', 'cubes', 'powder', 'bouillon'},
  'tomato': {'paste', 'ketchup', 'catsup'},
  'coconut': {'oil', 'grater', 'shredder'},
};

Set<String> extractMatchingKeywords(String text) {
  final clean = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  final words = clean
      .split(RegExp(r'\s+'))
      .where((w) => w.length >= 3 && !ingredientNoiseWords.contains(w));
  final result = <String>{};
  for (final w in words) {
    result.add(w);
    if (w.endsWith('ies') && w.length > 4) {
      result.add('${w.substring(0, w.length - 3)}y');
    } else if (w.endsWith('es') && w.length > 4) {
      result.add(w.substring(0, w.length - 2));
    } else if (w.endsWith('s') && w.length > 3) {
      result.add(w.substring(0, w.length - 1));
    }
  }
  return result;
}

bool _matchesPurchased(
  String text,
  Set<String> textKeywords,
  String purchasedName,
  Set<String> purchasedKeywords,
) {
  if (text.isEmpty || purchasedName.isEmpty) return false;

  // Filter out false positive compound derivatives:
  // e.g. buying "banana" must not match "banana ketchup", "banana heart", or "banana leaves"
  for (final pKeyword in purchasedKeywords) {
    final exclusions = compoundDerivativeExclusions[pKeyword];
    if (exclusions != null) {
      final hasExcludedTerm = textKeywords.any(exclusions.contains);
      final purchasedHadExcludedTerm =
          purchasedKeywords.any(exclusions.contains);
      if (hasExcludedTerm && !purchasedHadExcludedTerm) {
        return false;
      }
    }
  }

  return textKeywords.any((k) => purchasedKeywords.contains(k));
}

int _scoreRecipe(Recipe recipe, String pName, Set<String> pKeywords) {
  int score = 0;
  final titleLower = recipe.title.toLowerCase();
  final titleKeywords = extractMatchingKeywords(titleLower);

  // High bonus if title directly contains the ingredient (e.g. "Banana Oats Bites" for Banana)
  if (_matchesPurchased(titleLower, titleKeywords, pName, pKeywords)) {
    score += 10;
  }

  final ingredients = recipe.ingredients;
  if (ingredients != null) {
    for (int i = 0; i < ingredients.length; i++) {
      final ingName = ingredients[i].name.toLowerCase();
      final ingKeywords = extractMatchingKeywords(ingName);
      if (_matchesPurchased(ingName, ingKeywords, pName, pKeywords)) {
        if (i < 3) {
          score += 6; // Primary / featured ingredient
        } else {
          score += 3; // Secondary ingredient
        }
      }
    }
  }

  if (score > 0 && recipe.imageUrl.isNotEmpty) {
    score += 1;
  }

  return score;
}

/// Recipes whose title or ingredients match any purchased item.
///
/// Curates and ranks recipes by relevance and caps recommendations to
/// [maxPerIngredient] top recipes per purchased ingredient to prevent
/// overwhelming lists of 30+ recipes.
List<Recipe> unlockedRecipes(
  List<Recipe> allRecipes,
  Set<String> purchased, {
  int maxPerIngredient = 5,
}) {
  if (purchased.isEmpty || allRecipes.isEmpty) return const [];

  final cleanedPurchased = <String, Set<String>>{};
  for (final p in purchased) {
    final lower = p.toLowerCase().trim();
    if (lower.isNotEmpty) {
      final kws = extractMatchingKeywords(lower);
      if (kws.isNotEmpty) {
        cleanedPurchased[lower] = kws;
      }
    }
  }

  if (cleanedPurchased.isEmpty) return const [];

  final recipeScores = <String, int>{};
  final recipeMap = <String, Recipe>{};

  for (final entry in cleanedPurchased.entries) {
    final pName = entry.key;
    final pKeywords = entry.value;

    final scoredForIngredient = <Recipe, int>{};
    for (final recipe in allRecipes) {
      final score = _scoreRecipe(recipe, pName, pKeywords);
      if (score > 0) {
        scoredForIngredient[recipe] = score;
      }
    }

    final sortedEntries = scoredForIngredient.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Limit to the top most relevant recipes per purchased ingredient
    final topEntries = sortedEntries.take(maxPerIngredient);
    for (final e in topEntries) {
      final r = e.key;
      recipeScores[r.id] = (recipeScores[r.id] ?? 0) + e.value;
      recipeMap[r.id] = r;
    }
  }

  final results = recipeMap.values.toList();
  results.sort((a, b) {
    final scoreA = recipeScores[a.id] ?? 0;
    final scoreB = recipeScores[b.id] ?? 0;
    final byScore = scoreB.compareTo(scoreA);
    if (byScore != 0) return byScore;
    return a.title.compareTo(b.title);
  });

  return results;
}
