import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/core/utils/ingredient_noise_words.dart';
import 'package:palengkego/features/market/domain/market_repository.dart';
import 'package:palengkego/features/market/data/firebase_market_repository.dart';
import 'package:palengkego/features/market/data/mock_market_repository.dart';
import 'package:palengkego/features/market/domain/market_product.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';

import 'package:palengkego/features/profile/application/preferences_provider.dart';

/// Single explicit backend switch for the market catalog.
///
/// Firebase mode reads the live `vendorStalls` catalog (public read per
/// `firestore.rules`); dev/test/mock mode serves [MockMarketRepository].
final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  if (ref.watch(firebaseEnabledProvider)) {
    return FirebaseMarketRepository(ref.watch(firestoreProvider));
  }
  return MockMarketRepository();
});

final allVendorsProvider = FutureProvider<List<MarketVendor>>((ref) async {
  ref.watch(dataRefreshSignal);
  final blocked = ref.watch(
    preferencesProvider.select((s) => s.blockedStallIds),
  );
  final repository = ref.watch(marketRepositoryProvider);
  final vendors = await repository.getVendorsByCategory('All');
  return vendors
      .where((v) => !blocked.contains(v.id) && !blocked.contains(v.name))
      .toList();
});

final vendorsByCategoryProvider =
    FutureProvider.family<List<MarketVendor>, String>((ref, category) async {
      ref.watch(dataRefreshSignal);
      final blocked = ref.watch(
        preferencesProvider.select((s) => s.blockedStallIds),
      );
      final repository = ref.watch(marketRepositoryProvider);
      final vendors = await repository.getVendorsByCategory(category);
      return vendors
          .where((v) => !blocked.contains(v.id) && !blocked.contains(v.name))
          .toList();
    });

final discountedProductsProvider = FutureProvider<List<MarketProduct>>((
  ref,
) async {
  ref.watch(dataRefreshSignal);
  final repository = ref.watch(marketRepositoryProvider);
  final vendorsAsync = ref.watch(allVendorsProvider);
  final products = await repository.getDiscountedProducts();
  final vendors = vendorsAsync.value ?? [];
  final openVendorIds = vendors.where((v) => v.isOpen).map((v) => v.id).toSet();

  return products.where((p) => openVendorIds.contains(p.vendorId)).toList();
});

final allProductsProvider = FutureProvider<List<MarketProduct>>((ref) async {
  ref.watch(dataRefreshSignal);
  final repository = ref.watch(marketRepositoryProvider);
  return repository.getAllProducts();
});

/// Filters all products by the given query string (case-insensitive).
/// Matches on product name and category.
final searchProductsProvider =
    FutureProvider.family<List<MarketProduct>, String>((ref, query) async {
      final productsAsync = ref.watch(allProductsProvider);
      final products = productsAsync.value ?? [];
      final normalizedQuery = query.toLowerCase().trim();

      if (normalizedQuery.isEmpty) return [];

      return products
          .where((product) {
            return product.name.toLowerCase().contains(normalizedQuery) ||
                product.category.toLowerCase().contains(normalizedQuery);
          })
          .take(8)
          .toList();
    });

/// Filters all vendors by the given query string (case-insensitive).
final searchVendorsProvider = FutureProvider.family<List<MarketVendor>, String>(
  (ref, query) async {
    final vendorsAsync = ref.watch(allVendorsProvider);
    final vendors = vendorsAsync.value ?? [];
    final normalizedQuery = query.toLowerCase().trim();

    if (normalizedQuery.isEmpty) return [];

    return vendors
        .where((vendor) {
          return vendor.name.toLowerCase().contains(normalizedQuery) ||
              vendor.category.toLowerCase().contains(normalizedQuery);
        })
        .take(5)
        .toList();
  },
);

class RecommendedIngredientProduct {
  final MarketProduct product;
  final MarketVendor vendor;

  /// Service-level delivery estimate, or null when we have no basis for
  /// one — never a fabricated number.
  final String? estDeliveryTime;

  /// The platform's flat delivery fee (FeeConfig), not per-product fiction.
  final double deliveryFee;

  /// Real completed-order count for this product, or 0 when unknown — the
  /// UI hides the badge rather than inventing popularity.
  final int orderCount;
  final int relevanceScore;

  const RecommendedIngredientProduct({
    required this.product,
    required this.vendor,
    this.estDeliveryTime,
    this.deliveryFee = FeeConfig.deliveryFee,
    this.orderCount = 0,
    this.relevanceScore = 0,
  });
}

/// Calculates strict word-boundary token relevance score for a product given an ingredient query.
/// Returns 0 if the product is not a genuine match (e.g. excludes "rice" for "ice", "milkfish" for "milk").
int calculateIngredientRelevanceScore(
  String rawIngredientName,
  MarketProduct product,
) {
  final ingClean = rawIngredientName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .trim();

  final prodClean = product.name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .trim();

  final ingTokens = ingClean
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty && !ingredientNoiseWords.contains(t))
      .toList();

  // If query is only noise words (e.g. "fresh"), fall back to raw query tokens
  final queryTokens = ingTokens.isNotEmpty
      ? ingTokens
      : ingClean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  if (queryTokens.isEmpty) return 0;

  final prodTokens = prodClean
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toSet();

  // 1. Exact product name match
  if (ingClean == prodClean) return 1000;

  int score = 0;
  int matchedTokensCount = 0;

  for (final qToken in queryTokens) {
    // Exact whole-word match
    if (prodTokens.contains(qToken)) {
      matchedTokensCount++;
      score += 100;
    } else {
      // Check stem / plural prefix match (e.g. "mango" <-> "mangoes", "banana" <-> "bananas")
      bool stemMatched = false;
      for (final pToken in prodTokens) {
        if (pToken.startsWith(qToken) || qToken.startsWith(pToken)) {
          // Exclude false positive trailing substrings like "ice" in "rice"
          if (pToken.endsWith(qToken) && pToken != qToken) {
            continue;
          }
          // Length difference threshold
          if (qToken.length >= 3 &&
              (pToken.length - qToken.length).abs() <= 3) {
            stemMatched = true;
            break;
          }
        }
      }
      if (stemMatched) {
        matchedTokensCount++;
        score += 60;
      }
    }
  }

  if (matchedTokensCount == 0) return 0;

  // Boost score for multi-word matches
  final matchRatio = matchedTokensCount / queryTokens.length;
  return (score * matchRatio).round();
}

/// Generic provider to get recommended stores and products for any recipe ingredient name.
final recommendedStoresForIngredientProvider =
    FutureProvider.family<List<RecommendedIngredientProduct>, String>((
      ref,
      ingredientName,
    ) async {
      ref.watch(dataRefreshSignal);
      final allProds = await ref.watch(allProductsProvider.future);
      final allVends = await ref.watch(allVendorsProvider.future);

      final vendorMap = {for (var v in allVends) v.id: v};
      final List<RecommendedIngredientProduct> results = [];

      for (final prod in allProds) {
        final vendor = vendorMap[prod.vendorId];
        if (vendor == null) continue;

        final score = calculateIngredientRelevanceScore(ingredientName, prod);
        if (score > 0) {
          // No fabricated trust signals: real order counts are not available
          // on this path, so the badge stays hidden (orderCount 0) and the
          // delivery fee shown is the platform's flat fee.
          results.add(
            RecommendedIngredientProduct(
              product: prod,
              vendor: vendor,
              relevanceScore: score,
            ),
          );
        }
      }

      // Sort primarily by relevanceScore (descending), then vendor rating (descending)
      results.sort((a, b) {
        final scoreComp = b.relevanceScore.compareTo(a.relevanceScore);
        if (scoreComp != 0) return scoreComp;
        return b.vendor.rating.compareTo(a.vendor.rating);
      });

      return results;
    });
