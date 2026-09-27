import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/core/utils/ingredient_noise_words.dart';
import 'package:palengkego/features/market/domain/market_repository.dart';
import 'package:palengkego/features/market/data/mock_market_repository.dart';
import 'package:palengkego/features/market/domain/market_product.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/application/has_vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';

/// Single explicit backend switch for the market catalog.
final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MockMarketRepository();
});

final allVendorsProvider = FutureProvider<List<MarketVendor>>((ref) async {
  ref.watch(dataRefreshSignal);
  final blocked = ref.watch(preferencesProvider).blockedStallIds;
  final repository = ref.watch(marketRepositoryProvider);

  // 1. Base vendors from repository
  final baseVendors = await repository.getVendorsByCategory('All');
  final Map<String, MarketVendor> vendorMap = {
    for (final v in baseVendors) v.id: v,
  };

  // 2. Fetch approved / verified stalls from Supabase if connected
  final supabase = ref.watch(supabaseClientProvider);
  if (supabase != null) {
    try {
      final res = await supabase
          .from('stall_holders')
          .select()
          .or('is_kyc_approved.eq.true,kyc_status.eq.approved');
      if (res is List && res.isNotEmpty) {
        for (final item in res) {
          final row = Map<String, dynamic>.from(item as Map);
          final id = row['stall_holder_id'] as String? ??
              row['user_id'] as String? ??
              '';
          if (id.isEmpty) continue;

          final banner = row['banner_image_url'] as String?;
          final avatar = row['avatar_image_url'] as String?;
          final cat = row['category'] as String? ?? 'Fruits';
          final name = row['stall_name'] as String? ?? 'Stall Holder';

          final stallNumRaw = row['stall_number']?.toString().trim();
          final floorNumRaw = row['floor_number']?.toString().trim();
          String stallNum;
          if (stallNumRaw != null && stallNumRaw.isNotEmpty) {
            final hasBlockOrStall = stallNumRaw.toLowerCase().contains('stall') ||
                stallNumRaw.toLowerCase().contains('block');
            final cleanStall = hasBlockOrStall ? stallNumRaw : 'Stall $stallNumRaw';
            if (floorNumRaw != null &&
                floorNumRaw.isNotEmpty &&
                !cleanStall.toLowerCase().contains('floor')) {
              stallNum = '$cleanStall, Floor $floorNumRaw';
            } else {
              stallNum = cleanStall;
            }
          } else if (floorNumRaw != null && floorNumRaw.isNotEmpty) {
            stallNum = 'Floor $floorNumRaw';
          } else {
            stallNum = 'Stall 14';
          }
          final section = row['section'] as String? ??
              (floorNumRaw != null && floorNumRaw.isNotEmpty
                  ? 'Floor $floorNumRaw • $cat Section'
                  : '$cat Section');

          final fallbackImg = cat.toLowerCase().contains('fruit')
              ? 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?auto=format&fit=crop&q=80&w=600'
              : 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=600';

          final imageUrl = (banner != null && banner.isNotEmpty)
              ? banner
              : ((avatar != null && avatar.isNotEmpty)
                  ? avatar
                  : fallbackImg);

          vendorMap[id] = MarketVendor(
            id: id,
            name: name,
            category: cat,
            rating: (row['rating'] as num?)?.toDouble() ?? 5.0,
            isVerified: row['is_kyc_approved'] as bool? ??
                (row['kyc_status'] == 'approved'),
            distance: '0.5km',
            imageUrl: imageUrl,
            stallNumber: stallNum,
            marketSection: section,
            reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
            isOpen: row['is_open'] as bool? ?? true,
          );
        }
      }
    } catch (_) {}
  }

  // 3. Include currently verified logged-in vendor stall
  final user = ref.watch(authProvider);
  final hasStall =
      ref.watch(hasVendorStallProvider) || (user != null && user.isVendor);
  if (hasStall) {
    final myStall = ref.watch(vendorStallProvider);
    if (myStall.stallId.isNotEmpty) {
      final banner = myStall.bannerImage;
      final avatar = myStall.avatarImage;
      String stallNum;
      if (myStall.location.isNotEmpty) {
        stallNum = myStall.location;
      } else {
        final sNum = myStall.stallNumber?.trim();
        final fNum = myStall.floorNumber?.trim();
        if (sNum != null && sNum.isNotEmpty) {
          final hasBlockOrStall = sNum.toLowerCase().contains('stall') ||
              sNum.toLowerCase().contains('block');
          final cleanStall = hasBlockOrStall ? sNum : 'Stall $sNum';
          if (fNum != null && fNum.isNotEmpty && !cleanStall.toLowerCase().contains('floor')) {
            stallNum = '$cleanStall, Floor $fNum';
          } else {
            stallNum = cleanStall;
          }
        } else if (fNum != null && fNum.isNotEmpty) {
          stallNum = 'Floor $fNum';
        } else {
          stallNum = 'Stall 14';
        }
      }
      final sec = (myStall.section != null && myStall.section!.isNotEmpty)
          ? myStall.section!
          : (myStall.location.contains(',')
              ? myStall.location.split(',').sublist(1).join(',').trim()
              : '${myStall.category} Section');

      final fallbackImg = myStall.category.toLowerCase().contains('fruit')
          ? 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?auto=format&fit=crop&q=80&w=600'
          : 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=600';

      final imageUrl = (banner != null && banner.isNotEmpty)
          ? banner
          : ((avatar != null && avatar.isNotEmpty)
              ? avatar
              : fallbackImg);

      vendorMap[myStall.stallId] = MarketVendor(
        id: myStall.stallId,
        name: myStall.name,
        category: myStall.category,
        rating: 5.0,
        isVerified: true,
        distance: '0.5km',
        imageUrl: imageUrl,
        stallNumber: stallNum,
        marketSection: sec,
        reviewCount: 0,
        isOpen: myStall.isOpen,
      );
    }
  }

  return vendorMap.values
      .where((v) => !blocked.contains(v.id) && !blocked.contains(v.name))
      .toList();
});

final vendorsByCategoryProvider =
    FutureProvider.family<List<MarketVendor>, String>((ref, category) async {
      final all = await ref.watch(allVendorsProvider.future);
      if (category == 'All') return all;

      final normCat = category.toLowerCase().trim();
      return all.where((v) {
        final vCat = v.category.toLowerCase().trim();
        if (vCat == normCat) return true;
        if (vCat.contains(normCat) || normCat.contains(vCat)) return true;

        if (normCat == 'maritatas' || normCat == 'sari-sari') {
          if (vCat.contains('rice') ||
              vCat.contains('grains') ||
              vCat.contains('spice') ||
              vCat.contains('condiment')) {
            return true;
          }
        }
        return false;
      }).toList();
    });

/// Computes Popular Stalls for the Home Screen:
/// 1. Basis: Ratings + Sales/Review activity (resetting weekly).
/// 2. Category Diversity: At most 2 stalls per category qualify.
/// 3. Display Order: All qualified stalls are sorted strictly from highest to lowest
///    overall so that the #1 stall across the entire market appears first.
final popularVendorsProvider = FutureProvider<List<MarketVendor>>((ref) async {
  final allVendors = await ref.watch(allVendorsProvider.future);
  if (allVendors.isEmpty) return [];

  // Scoring function: rating (dominant 0-500 pts) + review/sales activity (0-50 pts) + verified bonus
  double computePopularityScore(MarketVendor v) {
    final ratingBase = v.rating * 100.0;
    final activityWeight = (v.reviewCount * 1.5).clamp(0.0, 50.0);
    final verifiedBonus = v.isVerified ? 20.0 : 0.0;
    return ratingBase + activityWeight + verifiedBonus;
  }

  // 1. Group stalls by category
  final Map<String, List<MarketVendor>> byCategory = {};
  for (final vendor in allVendors) {
    byCategory.putIfAbsent(vendor.category, () => []).add(vendor);
  }

  // 2. Select at most top 2 stalls per category
  final List<MarketVendor> qualifiedStalls = [];
  for (final categoryList in byCategory.values) {
    categoryList.sort((a, b) =>
        computePopularityScore(b).compareTo(computePopularityScore(a)));
    qualifiedStalls.addAll(categoryList.take(2));
  }

  // 3. Sort all selected stalls from highest to lowest overall
  qualifiedStalls.sort((a, b) =>
      computePopularityScore(b).compareTo(computePopularityScore(a)));

  return qualifiedStalls;
});

final discountedProductsProvider = FutureProvider<List<MarketProduct>>((
  ref,
) async {
  ref.watch(dataRefreshSignal);
  final repository = ref.watch(marketRepositoryProvider);
  final vendors = ref.watch(allVendorsProvider).value ?? const <MarketVendor>[];
  final products = await repository.getDiscountedProducts();
  if (vendors.isEmpty) {
    return products;
  }
  final openVendorIds = vendors.where((v) => v.isOpen).map((v) => v.id).toSet();

  return products.where((p) => openVendorIds.contains(p.vendorId)).toList();
});

final allProductsProvider = FutureProvider<List<MarketProduct>>((ref) async {
  ref.watch(dataRefreshSignal);
  final repository = ref.watch(marketRepositoryProvider);
  final baseProducts = await repository.getAllProducts();
  final Map<String, MarketProduct> productMap = {
    for (final p in baseProducts) p.id: p,
  };

  final supabase = ref.watch(supabaseClientProvider);
  if (supabase != null) {
    try {
      final rows = await supabase
          .from('products')
          .select()
          .eq('is_visible', true);

      if (rows is List && rows.isNotEmpty) {
        for (final item in rows) {
          final row = Map<String, dynamic>.from(item as Map);
          final id = row['product_id']?.toString() ?? '';
          if (id.isEmpty) continue;

          final unit = (row['unit'] as String? ?? 'kg').toLowerCase();
          final isPiece = unit == 'piece' || unit == 'pc';
          final price = (isPiece
                  ? (row['price_per_piece'] as num?)?.toDouble()
                  : (row['price_per_kg'] as num?)?.toDouble()) ??
              (row['price'] as num?)?.toDouble() ??
              0.0;
          final inStock = row['is_in_stock'] as bool? ?? true;
          final stock = (row['stock_quantity'] as num?)?.toDouble() ??
              (inStock ? 15.0 : 0.0);

          productMap[id] = MarketProduct(
            id: id,
            vendorId: row['stall_holder_id']?.toString() ?? '',
            name: row['product_name'] as String? ?? '',
            description: row['description'] as String? ?? 'Fresh product from vendor',
            category: row['category_tag'] as String? ?? 'Vegetables',
            price: price,
            unit: isPiece ? 'pc' : 'kg',
            imageUrl: row['image_url'] as String? ?? '',
            isActive: inStock,
            stockQuantity: stock,
            discountPercentage: (row['discount_percentage'] as num?)?.toDouble(),
          );
        }
      }
    } catch (_) {}
  }

  return productMap.values.toList();
});

/// Filters all products by the given query string (case-insensitive).
/// Matches on product name and category.
final searchProductsProvider =
    FutureProvider.family<List<MarketProduct>, String>((ref, query) async {
      final products = await ref.watch(allProductsProvider.future);
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
    final vendors = await ref.watch(allVendorsProvider.future);
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
