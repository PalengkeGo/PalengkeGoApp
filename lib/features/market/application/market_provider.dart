import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/core/utils/ingredient_noise_words.dart';
import 'package:palengkego/core/utils/image_url_resolver.dart';
import 'package:palengkego/features/market/domain/market_repository.dart';
import 'package:palengkego/features/market/data/mock_market_repository.dart';
import 'package:palengkego/features/market/domain/market_product.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/application/has_vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/data/mock_vendor_repository.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';

/// Single explicit backend switch for the market catalog.
final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MockMarketRepository();
});

final allVendorsProvider = FutureProvider<List<MarketVendor>>((ref) async {
  ref.watch(dataRefreshSignal);
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
          .select();
      if (res.isNotEmpty) {
        for (final item in res) {
          final row = Map<String, dynamic>.from(item as Map);
          final id = row['stall_holder_id'] as String? ??
              row['user_id'] as String? ??
              '';
          if (id.isEmpty) continue;

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

          final rawThumb = row['thumbnail_url'] as String? ??
              row['thumbnail_image_url'] as String? ??
              row['thumbnailImage'] as String?;
          final rawBanner = row['banner_image_url'] as String?;
          final rawAvatar = row['avatar_image_url'] as String?;

          final thumb = resolveImageUrl(rawThumb, client: supabase);
          final banner = resolveImageUrl(rawBanner, client: supabase);
          final avatar = resolveImageUrl(rawAvatar, client: supabase);

          final imageUrl = (thumb != null && thumb.isNotEmpty)
              ? thumb
              : ((banner != null && banner.isNotEmpty)
                  ? banner
                  : ((avatar != null && avatar.isNotEmpty)
                      ? avatar
                      : fallbackImg));

          final vendorObj = MarketVendor(
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
          vendorMap[id] = vendorObj;

          // If this stall matches an existing stall in vendorMap (by name or ID), update it too
          for (final existingKey in vendorMap.keys.toList()) {
            final ev = vendorMap[existingKey]!;
            if (ev.id == id || ev.name.toLowerCase().trim() == name.toLowerCase().trim()) {
              vendorMap[existingKey] = ev.copyWith(
                imageUrl: imageUrl,
                name: name,
                category: cat,
                stallNumber: stallNum,
                marketSection: section,
                isOpen: row['is_open'] as bool? ?? ev.isOpen,
              );
            }
          }
        }
      }
    } catch (_) {}
  }

  // 3. Include currently verified logged-in vendor stall
  final isVendor =
      ref.watch(authProvider.select((u) => u?.isVendor ?? false));
  final hasStall = ref.watch(hasVendorStallProvider) || isVendor;
  if (hasStall) {
    final myStall = ref.watch(vendorStallProvider);
    if (myStall.stallId.isNotEmpty) {
      final banner = myStall.bannerImage;
      final avatar = myStall.avatarImage;
      final thumb = myStall.thumbnailImage;
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

      final imageUrl = (thumb != null && thumb.isNotEmpty)
          ? thumb
          : ((banner != null && banner.isNotEmpty)
              ? banner
              : ((avatar != null && avatar.isNotEmpty)
                  ? avatar
                  : fallbackImg));

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

  // Always overlay saved stall branding from local vendor repository onto matching stalls
  try {
    final vRepo = ref.watch(vendorRepositoryProvider);
    final myStall = ref.watch(vendorStallProvider);
    final localStall = await vRepo.getVendorStall(myStall.stallId);
    final rawPhoto = (myStall.thumbnailImage != null && myStall.thumbnailImage!.isNotEmpty)
        ? myStall.thumbnailImage
        : (localStall.thumbnailImage != null && localStall.thumbnailImage!.isNotEmpty
            ? localStall.thumbnailImage
            : (myStall.bannerImage != null && myStall.bannerImage!.isNotEmpty
                ? myStall.bannerImage
                : (localStall.bannerImage != null && localStall.bannerImage!.isNotEmpty
                    ? localStall.bannerImage
                    : (myStall.avatarImage != null && myStall.avatarImage!.isNotEmpty
                        ? myStall.avatarImage
                        : localStall.avatarImage))));

    final effectivePhoto = resolveImageUrl(rawPhoto, client: supabase) ?? rawPhoto;

    if (effectivePhoto != null && effectivePhoto.isNotEmpty) {
      final targetNames = {
        myStall.name.toLowerCase().trim(),
      }..remove('');
      final targetIds = {
        myStall.stallId,
        myStall.ownerUid,
      }..remove('');

      for (final key in vendorMap.keys.toList()) {
        final v = vendorMap[key]!;
        if (targetIds.contains(v.id) || targetNames.contains(v.name.toLowerCase().trim())) {
          vendorMap[key] = v.copyWith(
            imageUrl: effectivePhoto,
            name: myStall.name.isNotEmpty ? myStall.name : v.name,
            category: myStall.category.isNotEmpty ? myStall.category : v.category,
            isOpen: myStall.isOpen,
          );
        }
      }
    }
  } catch (_) {}

  return vendorMap.values.toList();
});

final vendorsByCategoryProvider =
    FutureProvider.family<List<MarketVendor>, String>((ref, category) async {
      final all = await ref.watch(allVendorsProvider.future);
      final blocked =
          ref.watch(preferencesProvider.select((p) => p.blockedStallIds));
      final available = all
          .where((v) => !blocked.contains(v.id) && !blocked.contains(v.name))
          .toList();
      if (category == 'All') return available;

      final normCat = category.toLowerCase().trim();
      return available.where((v) {
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
  final allProducts = await ref.watch(allProductsProvider.future);

  final list = allProducts.where((p) => p.hasDiscount && (p.isActive || p.stockQuantity > 0)).toList();

  // Deduplicate products so the same item is not repeated
  final seenKeys = <String>{};
  final deduped = <MarketProduct>[];
  for (final p in list) {
    final key = '${p.vendorId}_${p.name.toLowerCase().trim()}';
    if (seenKeys.add(key)) {
      deduped.add(p);
    }
  }

  // If there are discounted items, ensure promo notifications exist in NotificationService
  if (deduped.isNotEmpty) {
    try {
      final notifService = ref.read(notificationServiceProvider);
      for (final p in deduped) {
        final existing = notifService.all.any((n) => n.referenceId?.contains(p.id) == true);
        if (!existing) {
          notifService.addNotification(
            AppNotification(
              id: 'promo_${p.id}',
              type: NotificationType.promo,
              target: NotificationTarget.both,
              title: 'Special Offers Alert: Discounted Items Available!',
              body:
                  '${p.name} is now on Special Offer with ${p.discountPercentage?.toInt() ?? 0}% off! Check it out now on Special Offers.',
              createdAt: DateTime.now(),
              referenceId: '${p.vendorId}:${p.id}',
            ),
          );
        }
      }
    } catch (_) {}
  }

  return deduped;
});

final allProductsProvider = FutureProvider<List<MarketProduct>>((ref) async {
  ref.watch(dataRefreshSignal);
  final repository = ref.watch(marketRepositoryProvider);
  final baseProducts = await repository.getAllProducts();
  final Map<String, MarketProduct> productMap = {
    for (final p in baseProducts) p.id: p,
  };

  // Include custom products from local vendor repository for all relevant vendor IDs
  try {
    final vendorRepo = ref.read(vendorRepositoryProvider);
    if (vendorRepo is MockVendorRepository) {
      final allCustom = await vendorRepo.getAllCustomProducts();
      for (final p in allCustom) {
        productMap[p.id] = p;
      }
    }
    final myStall = ref.read(vendorStallProvider);
    final user = ref.read(authProvider);
    final idsToCheck = {
      'v1',
      'stall_holder-001',
      if (myStall.stallId.isNotEmpty) myStall.stallId,
      if (myStall.ownerUid.isNotEmpty) myStall.ownerUid,
      if (user?.uid != null) user!.uid,
    };
    for (final vId in idsToCheck) {
      final localVendorProducts = await vendorRepo.getVendorProducts(vId);
      for (final p in localVendorProducts) {
        productMap[p.id] = p;
      }
    }
  } catch (_) {}

  final supabase = ref.watch(supabaseClientProvider);
  if (supabase != null) {
    try {
      final rows = await supabase
          .from('products')
          .select();

      if (rows.isNotEmpty) {
        for (final item in rows) {
          final row = Map<String, dynamic>.from(item as Map);
          final id = row['product_id']?.toString() ?? row['id']?.toString() ?? '';
          if (id.isEmpty) continue;

          final isVis = row['is_visible'] as bool? ?? true;
          if (!isVis) continue;

          final unit = (row['unit'] as String? ?? 'kg').toLowerCase();
          final isPiece = unit == 'piece' || unit == 'pc';
          final price = (isPiece
                  ? (row['price_per_piece'] as num?)?.toDouble()
                  : (row['price_per_kg'] as num?)?.toDouble()) ??
              (row['price'] as num?)?.toDouble() ??
              0.0;
          final inStock = row['is_in_stock'] as bool? ?? true;
          final rawStock = (row['stock_quantity'] as num?)?.toDouble() ??
              (row['stock'] as num?)?.toDouble() ??
              (row['quantity'] as num?)?.toDouble();
          final stock = rawStock ?? (inStock ? 5.0 : 0.0);

          final vId = row['stall_holder_id']?.toString();
          final effectiveVendorId = (vId != null && vId.isNotEmpty) ? vId : 'v1';
          final rawImg = row['image_url'] as String? ??
              row['imageUrl'] as String? ??
              row['image'] as String? ??
              row['photo_url'] as String? ??
              row['photo'] as String? ??
              row['image_path'] as String? ??
              row['img_url'] as String? ??
              '';
          var img = resolveImageUrl(rawImg, client: supabase) ?? rawImg;
          if (img.isEmpty && productMap.containsKey(id) && productMap[id]!.imageUrl.isNotEmpty) {
            img = productMap[id]!.imageUrl;
          }

          final double? remoteDiscount =
              (row['discount_percentage'] as num?)?.toDouble() ??
              (row['discount'] as num?)?.toDouble() ??
              (row['discountPercentage'] as num?)?.toDouble() ??
              (row['discount_percent'] as num?)?.toDouble();

          final prodName = row['product_name'] as String? ?? '';
          final normName = prodName.toLowerCase().trim();

          // Find if there is an existing product entry with matching ID or Name
          String? matchedKey;
          if (productMap.containsKey(id)) {
            matchedKey = id;
          } else if (normName.isNotEmpty) {
            for (final entry in productMap.entries) {
              if (entry.value.name.toLowerCase().trim() == normName) {
                matchedKey = entry.key;
                break;
              }
            }
          }

          final double? finalDiscount =
              remoteDiscount ?? (matchedKey != null ? productMap[matchedKey]?.discountPercentage : null);

          final effectiveStock = (stock > 0 || !inStock) ? stock : 5.0;

          if (matchedKey != null) {
            final existing = productMap[matchedKey]!;
            final updatedImg = img.isNotEmpty ? img : existing.imageUrl;
            final updatedProduct = existing.copyWith(
              name: prodName.isNotEmpty ? prodName : existing.name,
              price: price > 0 ? price : existing.price,
              unit: isPiece ? 'pc' : existing.unit,
              imageUrl: updatedImg,
              isActive: inStock,
              stockQuantity: effectiveStock,
              discountPercentage: finalDiscount,
              vendorId: effectiveVendorId,
            );
            productMap[matchedKey] = updatedProduct;
            if (id != matchedKey) {
              productMap[id] = updatedProduct;
            }
          } else {
            productMap[id] = MarketProduct(
              id: id,
              vendorId: effectiveVendorId,
              name: prodName,
              description: row['description'] as String? ?? 'Fresh product from vendor',
              category: row['category_tag'] as String? ?? 'Vegetables',
              price: price,
              unit: isPiece ? 'pc' : 'kg',
              imageUrl: img,
              isActive: inStock,
              stockQuantity: effectiveStock,
              discountPercentage: finalDiscount,
            );
          }
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
