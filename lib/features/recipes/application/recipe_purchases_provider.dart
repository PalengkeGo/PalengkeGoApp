import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/utils/ingredient_noise_words.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';

class ManualPurchasedIngredientsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return {};
  }

  void markAsPurchased(String ingredientName) {
    state = {...state, ingredientName.toLowerCase().trim()};
  }

  void unmarkAsPurchased(String ingredientName) {
    final updated = Set<String>.from(state);
    updated.remove(ingredientName.toLowerCase().trim());
    state = updated;
  }

  void toggleIngredient(String ingredientName) {
    final key = ingredientName.toLowerCase().trim();
    if (state.contains(key)) {
      unmarkAsPurchased(key);
    } else {
      markAsPurchased(key);
    }
  }
}

final manualPurchasedIngredientsProvider =
    NotifierProvider<ManualPurchasedIngredientsNotifier, Set<String>>(
      ManualPurchasedIngredientsNotifier.new,
    );

/// Provides a consolidated Set of normalized product/ingredient names that the user has purchased
/// via placed orders or manual user actions.
final purchasedIngredientsProvider = Provider<Set<String>>((ref) {
  final ordersAsync = ref.watch(orderServiceProvider);
  final manualPurchases = ref.watch(manualPurchasedIngredientsProvider);
  final purchasedNames = <String>{...manualPurchases};

  ordersAsync.whenData((orders) {
    for (final order in orders) {
      if (order.status.name.toLowerCase() != 'cancelled' &&
          order.status.name.toLowerCase() != 'rejected') {
        for (final item in order.items) {
          purchasedNames.add(item.productName.toLowerCase().trim());
        }
      }
    }
  });

  return purchasedNames;
});

/// Generic helper to test whether a recipe ingredient is purchased.
/// Uses strict word boundary token matching to prevent false positives (e.g. "Beef Pares Rice" matching "Ice").
bool isIngredientPurchased(String ingredientName, Set<String> purchasedItems) {
  final ingClean = ingredientName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .trim();

  if (purchasedItems.contains(ingClean)) {
    return true;
  }

  final ingTokens = ingClean
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty && !ingredientNoiseWords.contains(t))
      .toList();

  final queryTokens = ingTokens.isNotEmpty
      ? ingTokens
      : ingClean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  if (queryTokens.isEmpty) return false;

  for (final purchasedItem in purchasedItems) {
    final itemClean = purchasedItem
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .trim();

    if (ingClean == itemClean) return true;

    final itemTokens = itemClean
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toSet();

    // All query tokens must match whole words in the purchased item
    bool allMatched = true;
    for (final qToken in queryTokens) {
      if (!itemTokens.contains(qToken)) {
        // Stem check
        bool stemMatched = false;
        for (final iToken in itemTokens) {
          if (iToken.startsWith(qToken) || qToken.startsWith(iToken)) {
            if (iToken.endsWith(qToken) && iToken != qToken) {
              continue; // Skip "ice" in "rice"
            }
            if (qToken.length >= 3 &&
                (iToken.length - qToken.length).abs() <= 3) {
              stemMatched = true;
              break;
            }
          }
        }
        if (!stemMatched) {
          allMatched = false;
          break;
        }
      }
    }

    if (allMatched) return true;
  }

  return false;
}
