import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/core/mock/mock_data.dart';
import 'package:palengkego/features/vendors/data/mock_vendor_repository.dart';
import 'package:palengkego/core/utils/image_url_resolver.dart';
import 'package:palengkego/features/vendors/domain/vendor_repository.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';
import 'package:palengkego/features/vendors/domain/vendor_profile.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';

final vendorRepositoryProvider = Provider<VendorRepository>((ref) {
  try {
    final prefs = ref.watch(sharedPreferencesProvider);
    return MockVendorRepository(prefs);
  } catch (_) {
    return MockVendorRepository();
  }
});

final vendorProfileProvider = FutureProvider.family<VendorProfile, String>((
  ref,
  vendorId,
) async {
  // 1. Try to find the vendor in allVendorsProvider (authoritative list of market stalls)
  MarketVendor? marketVendor;
  try {
    final allVendors = await ref.watch(allVendorsProvider.future);
    marketVendor = allVendors.where((v) =>
        v.id == vendorId ||
        v.id.toLowerCase() == vendorId.toLowerCase() ||
        (vendorId.isNotEmpty && v.name.toLowerCase().trim() == vendorId.toLowerCase().trim())
    ).firstOrNull;
  } catch (_) {}

  // 2. Check Supabase stall_holders FIRST if connected
  final supabase = ref.watch(supabaseClientProvider);
  if (supabase != null) {
    try {
      Map<String, dynamic>? res;
      try {
        res = await supabase
            .from('stall_holders')
            .select()
            .eq('stall_holder_id', vendorId)
            .maybeSingle();
      } catch (_) {}
      if (res == null) {
        try {
          res = await supabase
              .from('stall_holders')
              .select()
              .eq('user_id', vendorId)
              .maybeSingle();
        } catch (_) {}
      }
      if (res == null) {
        final queryName = marketVendor?.name ?? vendorId;
        if (queryName.isNotEmpty) {
          try {
            res = await supabase
                .from('stall_holders')
                .select()
                .eq('stall_name', queryName)
                .maybeSingle();
          } catch (_) {}
        }
      }

      if (res != null) {
        final stallNum = res['stall_number']?.toString();
        final floorNum = res['floor_number']?.toString();
        final section = res['section']?.toString();
        final category = res['category'] as String? ??
            marketVendor?.category ??
            'Fruits';
        final stallName = res['stall_name'] as String? ??
            marketVendor?.name ??
            'Stall Holder';

        String stallLoc = marketVendor?.stallNumber ?? 'Market Stall';
        if (stallNum != null && stallNum.isNotEmpty) {
          final prefix = (stallNum.toLowerCase().contains('stall') ||
                  stallNum.toLowerCase().contains('block'))
              ? stallNum
              : 'Stall $stallNum';
          stallLoc = '$prefix, Floor ${floorNum ?? '1'}';
          if (section != null && section.isNotEmpty) {
            stallLoc += ' • $section';
          }
        }

        final myStall = ref.watch(vendorStallProvider);
        final isMyStall = stallName.toLowerCase() == myStall.name.toLowerCase() ||
            res['stall_holder_id'] == myStall.stallId ||
            res['user_id'] == myStall.ownerUid;

        final banner = res['banner_image_url'] as String? ??
            res['banner'] as String? ??
            res['thumbnail_url'] as String? ??
            (isMyStall ? myStall.bannerImage : null);
        final avatar = res['avatar_image_url'] as String? ??
            res['avatar'] as String? ??
            res['avatar_url'] as String? ??
            res['profile_photo'] as String? ??
            res['photo_url'] as String? ??
            res['thumbnail_url'] as String? ??
            (isMyStall ? myStall.avatarImage : null);
        final desc = res['description'] as String? ??
            (isMyStall && myStall.description.isNotEmpty ? myStall.description : null);

        String? phone = res['phone_number'] as String?;
        final ownerUid = (res['user_id'] ?? res['stall_holder_id'])?.toString();
        if ((phone == null || phone.isEmpty) && ownerUid != null) {
          try {
            final userRow = await supabase
                .from('users')
                .select('phone_number')
                .eq('user_id', ownerUid)
                .maybeSingle();
            phone = userRow?['phone_number'] as String?;
          } catch (_) {}
        }
        if (phone == null || phone.isEmpty) {
          final currentUser = ref.read(authProvider);
          if (currentUser?.uid == ownerUid &&
              currentUser?.phoneNumber != null &&
              currentUser!.phoneNumber!.isNotEmpty) {
            phone = currentUser.phoneNumber;
          } else {
            phone = '+63 912 345 6789';
          }
        }

        final double rating = (res['average_rating'] as num?)?.toDouble() ??
            (res['rating'] as num?)?.toDouble() ??
            marketVendor?.rating ??
            5.0;
        final int reviewCount = (res['total_ratings'] as num?)?.toInt() ??
            (res['review_count'] as num?)?.toInt() ??
            marketVendor?.reviewCount ??
            0;

        final bannerResolved = resolveImageUrl(banner, client: supabase);
        final avatarResolved = resolveImageUrl(avatar, client: supabase);
        final effectiveImg = (bannerResolved != null && bannerResolved.isNotEmpty)
            ? bannerResolved
            : ((marketVendor?.imageUrl != null && marketVendor!.imageUrl.isNotEmpty)
                ? (resolveImageUrl(marketVendor.imageUrl, client: supabase) ?? marketVendor.imageUrl)
                : (category.toLowerCase().contains('fruit')
                    ? 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?auto=format&fit=crop&q=80&w=800'
                    : 'assets/images/ncpm-onboarding.jpg'));

        final effectiveAvatar = (avatarResolved != null && avatarResolved.isNotEmpty)
            ? avatarResolved
            : ((marketVendor?.imageUrl != null && marketVendor!.imageUrl.isNotEmpty)
                ? (resolveImageUrl(marketVendor.imageUrl, client: supabase) ?? marketVendor.imageUrl)
                : '');

        return VendorProfile(
          id: res['stall_holder_id'] as String? ?? marketVendor?.id ?? vendorId,
          name: stallName,
          category: category,
          rating: rating,
          reviewCount: reviewCount,
          isOpen: res['is_open'] as bool? ?? marketVendor?.isOpen ?? true,
          stallLocation: stallLoc,
          imageUrl: effectiveImg,
          avatarUrl: effectiveAvatar,
          phoneNumber: phone,
          description: (desc != null && desc.isNotEmpty)
              ? desc
              : 'Fresh $category directly to your doorstep. Quality and freshness guaranteed!',
        );
      }
    } catch (_) {}
  }

  // 3. If marketVendor was found in allVendorsProvider, use its authoritative market card info
  if (marketVendor != null) {
    final myStall = ref.watch(vendorStallProvider);
    final isBritanico = marketVendor.name.toLowerCase().contains('britanico') || myStall.name.toLowerCase().contains('britanico');
    final isMyStall = (marketVendor.name.toLowerCase().trim() == myStall.name.toLowerCase().trim() && (!isBritanico || marketVendor.id != 'v1')) ||
        (marketVendor.id == myStall.stallId && marketVendor.id != 'v1') ||
        (!isBritanico && (myStall.stallId == 'v1' || myStall.stallId == 'stall holder-001') && marketVendor.id == 'v1');

    final effectiveBanner = (isMyStall && myStall.bannerImage != null && myStall.bannerImage!.isNotEmpty)
        ? myStall.bannerImage!
        : marketVendor.imageUrl;
    final effectiveAvatar = (isMyStall && myStall.avatarImage != null && myStall.avatarImage!.isNotEmpty)
        ? myStall.avatarImage!
        : (marketVendor.imageUrl.isNotEmpty ? marketVendor.imageUrl : '');
    final effectiveDesc = (isMyStall && myStall.description.isNotEmpty)
        ? myStall.description
        : (marketVendor.description != null && marketVendor.description!.isNotEmpty
            ? marketVendor.description!
            : 'Fresh ${marketVendor.category.toLowerCase()} directly to your doorstep. Quality and freshness guaranteed!');

    return VendorProfile(
      id: marketVendor.id,
      name: marketVendor.name,
      category: marketVendor.category,
      rating: marketVendor.rating,
      reviewCount: marketVendor.reviewCount,
      isOpen: marketVendor.isOpen,
      stallLocation: (marketVendor.stallNumber != null && marketVendor.stallNumber!.isNotEmpty)
          ? marketVendor.stallNumber!
          : ((marketVendor.marketSection != null && marketVendor.marketSection!.isNotEmpty)
              ? marketVendor.marketSection!
              : 'Market Stall'),
      imageUrl: effectiveBanner,
      avatarUrl: effectiveAvatar,
      phoneNumber: '+63 912 345 6789',
      description: effectiveDesc,
    );
  }

  // 4. Only if the logged-in user IS a vendor and this is THEIR stall, use live vendor stall data
  final user = ref.watch(authProvider);
  final isVendor = user != null && user.isVendor;
  final myStall = ref.watch(vendorStallProvider);

  if (isVendor &&
      (vendorId == myStall.stallId ||
          vendorId == myStall.ownerUid ||
          vendorId == user.uid)) {
    final stallLocation = myStall.location.isNotEmpty
        ? myStall.location
        : (myStall.stallNumber != null && myStall.stallNumber!.isNotEmpty
            ? 'Stall ${myStall.stallNumber}, ${myStall.section ?? '${myStall.category} Section'}'
            : 'Stall 14, Wet Market Section');

    final image = (myStall.bannerImage != null && myStall.bannerImage!.isNotEmpty)
        ? myStall.bannerImage!
        : (myStall.category.toLowerCase().contains('fruit')
            ? 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?auto=format&fit=crop&q=80&w=800'
            : 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=800');

    return VendorProfile(
      id: myStall.stallId,
      name: myStall.name,
      category: myStall.category,
      rating: myStall.totalRatings > 0 ? myStall.averageRating : 5.0,
      reviewCount: myStall.totalRatings,
      isOpen: myStall.isOpen,
      stallLocation: stallLocation,
      imageUrl: image,
      avatarUrl: myStall.avatarImage ?? '',
      phoneNumber: '+63 912 345 6789',
      description: myStall.description.isNotEmpty
          ? myStall.description
          : 'Fresh ${myStall.category.toLowerCase()} directly to your doorstep. Quality and freshness guaranteed!',
    );
  }

  // 5. Fallback to repository
  final repository = ref.read(vendorRepositoryProvider);
  return repository.getVendorProfile(vendorId);
});

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String _sanitizeCategoryTag(String category) {
  final trimmed = category.trim();
  final lower = trimmed.toLowerCase();
  if (lower == 'beef' || lower == 'pork' || lower == 'meat') {
    return 'Meat';
  }
  if (lower.contains('fish')) {
    if (lower.contains('dry') || lower.contains('dried')) {
      return 'Dried Fish';
    }
    return 'Fresh Fish';
  }
  if (lower.contains('chicken') || lower.contains('poultry')) {
    return 'Chicken';
  }
  if (lower.contains('fruit')) {
    return 'Fruits';
  }
  if (lower.contains('veg')) {
    return 'Vegetables';
  }
  if (lower.contains('maritata')) {
    return 'Maritatas';
  }
  if (lower.contains('sari') ||
      lower.contains('grocery') ||
      lower.contains('snack')) {
    return 'Sari-Sari';
  }
  const valid = [
    'Fresh Fish',
    'Dried Fish',
    'Fruits',
    'Meat',
    'Chicken',
    'Vegetables',
    'Maritatas',
    'Sari-Sari',
  ];
  for (final v in valid) {
    if (v.toLowerCase() == lower) return v;
  }
  return 'Vegetables';
}

final vendorProductsProvider =
    FutureProvider.family<List<VendorProduct>, String>((ref, vendorId) async {
      ref.watch(dataRefreshSignal);

      final List<VendorProduct> combined = [];
      final Set<String> seenIds = {};
      final Set<String> seenNames = {};

      final supabase = ref.watch(supabaseClientProvider);
      if (supabase != null) {
        try {
          String targetStallId = vendorId;
          Map<String, dynamic>? stallRes;
          try {
            stallRes = await supabase
                .from('stall_holders')
                .select('stall_holder_id')
                .eq('stall_holder_id', vendorId)
                .maybeSingle();
          } catch (_) {}
          if (stallRes == null) {
            try {
              stallRes = await supabase
                  .from('stall_holders')
                  .select('stall_holder_id')
                  .eq('user_id', vendorId)
                  .maybeSingle();
            } catch (_) {}
          }
          if (stallRes == null) {
            try {
              stallRes = await supabase
                  .from('stall_holders')
                  .select('stall_holder_id')
                  .eq('stall_name', vendorId)
                  .maybeSingle();
            } catch (_) {}
          }
          if (stallRes != null && stallRes['stall_holder_id'] != null) {
            targetStallId = stallRes['stall_holder_id'].toString();
          }

          List<dynamic> rows = [];
          try {
            rows = await supabase
                .from('products')
                .select()
                .eq('stall_holder_id', targetStallId);
          } catch (_) {}
          if (rows.isEmpty && targetStallId != vendorId) {
            try {
              rows = await supabase
                .from('products')
                .select()
                .eq('stall_holder_id', vendorId);
            } catch (_) {}
          }

          if (rows.isNotEmpty) {
            for (final item in rows) {
              final row = Map<String, dynamic>.from(item as Map);
              final unit = (row['unit'] as String? ?? 'kg').toLowerCase();
              final isPiece = unit == 'piece' || unit == 'pc';
              final price = (isPiece
                      ? (row['price_per_piece'] as num?)?.toDouble()
                      : (row['price_per_kg'] as num?)?.toDouble()) ??
                  (row['price'] as num?)?.toDouble() ??
                  0.0;
              final inStock = row['is_in_stock'] as bool? ??
                  row['is_visible'] as bool? ??
                  true;
              final rawStock = (row['stock_quantity'] as num?)?.toDouble() ??
                  (row['stock'] as num?)?.toDouble() ??
                  (row['quantity'] as num?)?.toDouble();
              final stock = rawStock ?? (inStock ? 5.0 : 0.0);

              final p = VendorProduct(
                id: row['product_id']?.toString() ??
                    row['id']?.toString() ??
                    'prod_${row['product_name'] ?? targetStallId}',
                vendorId: row['stall_holder_id']?.toString() ?? targetStallId,
                name: row['product_name'] as String? ??
                    row['name'] as String? ??
                    '',
                description: row['description'] as String? ??
                    'Fresh product from vendor',
                category: row['category_tag'] as String? ??
                    row['category'] as String? ??
                    'Vegetables',
                price: price,
                unit: isPiece ? 'pc' : 'kg',
                imageUrl: () {
                  final rawUrl = row['image_url'] as String? ??
                      row['imageUrl'] as String? ??
                      row['image'] as String? ??
                      row['photo_url'] as String? ??
                      row['photo'] as String? ??
                      row['image_path'] as String? ??
                      row['img_url'] as String?;
                  final resolved = resolveImageUrl(rawUrl, client: supabase);
                  if (resolved != null && resolved.isNotEmpty) return resolved;
                  final pName = row['product_name'] as String? ??
                      row['name'] as String? ??
                      '';
                  final cTag = row['category_tag'] as String? ??
                      row['category'] as String? ??
                      'Vegetables';
                  return productFallbackImage(pName, cTag);
                }(),
                isActive: inStock && stock > 0,
                stockQuantity: stock,
                discountPercentage:
                    (row['discount_percentage'] as num?)?.toDouble() ??
                    (row['discount'] as num?)?.toDouble() ??
                    (row['discountPercentage'] as num?)?.toDouble() ??
                    (row['discount_percent'] as num?)?.toDouble(),
              );
              combined.add(p);
              seenIds.add(p.id);
              seenNames.add(p.name.toLowerCase().trim());
            }
          }
        } catch (e) {
          debugPrint('Error fetching products from Supabase: $e');
        }
      }

      // Merge local products from repository
      final repository = ref.read(vendorRepositoryProvider);
      final local = await repository.getVendorProducts(vendorId);

      bool isLocalMissing(String path) {
        if (path.isEmpty) return true;
        if (path.startsWith('http://') ||
            path.startsWith('https://') ||
            path.startsWith('assets/') ||
            path.startsWith('data:')) {
          return false;
        }
        if (kIsWeb) return false;
        try {
          final clean = path.replaceFirst('file://', '');
          final f = File(clean);
          return !f.existsSync() || f.lengthSync() == 0;
        } catch (_) {
          return true;
        }
      }

      // Backfill missing imagery or stock from local state if Supabase row had them empty
      for (int i = 0; i < combined.length; i++) {
        final cp = combined[i];
        final match = local.where(
          (l) => l.id == cp.id || l.name.toLowerCase().trim() == cp.name.toLowerCase().trim(),
        ).firstOrNull;
        if (match != null) {
          bool needsUpdate = false;
          String img = cp.imageUrl;
          double st = cp.stockQuantity;
          if ((img.isEmpty || isLocalMissing(img)) &&
              match.imageUrl.isNotEmpty &&
              !isLocalMissing(match.imageUrl)) {
            img = match.imageUrl;
            needsUpdate = true;
          }
          if (st <= 0.0 && match.stockQuantity > 0.0) {
            st = match.stockQuantity;
            needsUpdate = true;
          }
          double? disc = cp.discountPercentage ?? match.discountPercentage;
          if (disc != cp.discountPercentage) {
            needsUpdate = true;
          }
          if (needsUpdate) {
            combined[i] = cp.copyWith(
              imageUrl: img,
              stockQuantity: st,
              discountPercentage: disc,
              isActive: cp.isActive && st > 0,
            );
          }
        }

        // Fallback to MockDataService products or productFallbackImage if imagery is still empty
        if (combined[i].imageUrl.isEmpty || isLocalMissing(combined[i].imageUrl)) {
          final mockMatch = MockDataService.products.where((mp) {
            final mpName = (mp['name'] as String? ?? '').toLowerCase().trim();
            final cpName = combined[i].name.toLowerCase().trim();
            return mpName == cpName || cpName.contains(mpName) || mpName.contains(cpName);
          }).firstOrNull;
          if (mockMatch != null && mockMatch['imageUrl'] != null) {
            final fallbackUrl = mockMatch['imageUrl'] as String;
            if (fallbackUrl.isNotEmpty) {
              combined[i] = combined[i].copyWith(imageUrl: fallbackUrl);
            }
          }
          if (combined[i].imageUrl.isEmpty || isLocalMissing(combined[i].imageUrl)) {
            combined[i] = combined[i].copyWith(
              imageUrl: productFallbackImage(combined[i].name, combined[i].category),
            );
          }
        }
      }

      for (final p in local) {
        final normName = p.name.toLowerCase().trim();
        if (!seenIds.contains(p.id) && !seenNames.contains(normName)) {
          final effectiveP = (p.imageUrl.isEmpty || isLocalMissing(p.imageUrl))
              ? p.copyWith(imageUrl: productFallbackImage(p.name, p.category))
              : p;
          combined.add(effectiveP);
          seenIds.add(p.id);
          seenNames.add(normName);
        }
      }

      return combined;
    });

/// Full stall record for the given stallId (vendor-facing).
final vendorStallByIdProvider = FutureProvider.family<VendorStall, String>((
  ref,
  stallId,
) async {
  return ref.read(vendorRepositoryProvider).getVendorStall(stallId);
});

class VendorProductsManager {
  final Ref ref;
  final String vendorId;

  VendorProductsManager(this.ref, this.vendorId);

  Future<void> addProduct(VendorProduct product) async {
    VendorProduct productToAdd = product;
    final client = ref.read(supabaseClientProvider);
    String effectiveStallId = vendorId;

    if (client != null) {
      try {
        final stallRes = await client
            .from('stall_holders')
            .select('stall_holder_id')
            .or('stall_holder_id.eq.$vendorId,user_id.eq.$vendorId')
            .maybeSingle();

        if (stallRes != null && stallRes['stall_holder_id'] != null) {
          effectiveStallId = stallRes['stall_holder_id'].toString();
        } else {
          // If stall_holder row doesn't exist yet in Supabase, ensure it so foreign key passes
          try {
            await client.from('stall_holders').upsert({
              'stall_holder_id': effectiveStallId,
              'user_id': effectiveStallId,
              'stall_name': 'My Stall',
              'is_kyc_approved': true,
              'kyc_status': 'approved',
              'is_open': true,
            }, onConflict: 'stall_holder_id');
          } catch (_) {}
        }

        final isPiece = product.unit.toLowerCase() == 'pc' ||
            product.unit.toLowerCase() == 'piece';
        final categoryTag = _sanitizeCategoryTag(product.category);

        final payload = <String, dynamic>{
          'stall_holder_id': effectiveStallId,
          'product_name': product.name,
          'category_tag': categoryTag,
          'price_per_kg': isPiece ? null : product.price,
          'price_per_piece': isPiece ? product.price : null,
          'unit': isPiece ? 'piece' : 'kg',
          'image_url': product.imageUrl,
          'is_in_stock': product.isActive && product.stockQuantity > 0,
          'is_visible': product.isActive,
          'stock_quantity': product.stockQuantity,
          'description': product.description,
          if (product.discountPercentage != null)
            'discount_percentage': product.discountPercentage,
        };

        if (_uuidPattern.hasMatch(product.id)) {
          payload['product_id'] = product.id;
        }

        try {
          final inserted = await client
              .from('products')
              .insert(payload)
              .select()
              .maybeSingle();

          if (inserted != null && inserted['product_id'] != null) {
            productToAdd = product.copyWith(
              id: inserted['product_id'].toString(),
              vendorId: effectiveStallId,
            );
          }
        } catch (e) {
          // If schema doesn't have stock_quantity column yet, retry without it
          if (e.toString().contains('stock_quantity') || e.toString().contains('column')) {
            try {
              final fallbackPayload = Map<String, dynamic>.from(payload)..remove('stock_quantity');
              final inserted = await client
                  .from('products')
                  .insert(fallbackPayload)
                  .select()
                  .maybeSingle();
              if (inserted != null && inserted['product_id'] != null) {
                productToAdd = product.copyWith(
                  id: inserted['product_id'].toString(),
                  vendorId: effectiveStallId,
                );
              }
            } catch (_) {}
          }
          debugPrint('Error inserting product into Supabase: $e');
        }
      } catch (e) {
        debugPrint('Error preparing product insert: $e');
      }
    }

    final repository = ref.read(vendorRepositoryProvider);
    await repository.addVendorProduct(productToAdd.copyWith(vendorId: vendorId));
    if (effectiveStallId != vendorId) {
      await repository.addVendorProduct(productToAdd.copyWith(vendorId: effectiveStallId));
    }
    ref.invalidate(vendorProductsProvider(vendorId));
    if (effectiveStallId != vendorId) {
      ref.invalidate(vendorProductsProvider(effectiveStallId));
    }
    ref.invalidate(allProductsProvider);
    ref.invalidate(discountedProductsProvider);
    ref.read(dataRefreshSignal.notifier).notify();
  }

  Future<void> updateProduct(VendorProduct product) async {
    final client = ref.read(supabaseClientProvider);
    if (client != null) {
      try {
        String effectiveStallId = vendorId;
        final stallRes = await client
            .from('stall_holders')
            .select('stall_holder_id')
            .or('stall_holder_id.eq.$vendorId,user_id.eq.$vendorId')
            .maybeSingle();
        if (stallRes != null && stallRes['stall_holder_id'] != null) {
          effectiveStallId = stallRes['stall_holder_id'].toString();
        } else {
          final myStall = ref.read(vendorStallProvider);
          final user = ref.read(authProvider);
          final uid = user?.uid ?? vendorId;
          final fallbackStallId = myStall.stallId.isNotEmpty ? myStall.stallId : vendorId;
          try {
            await client.from('stall_holders').upsert({
              'stall_holder_id': fallbackStallId,
              'user_id': uid,
              'stall_name': myStall.name.isNotEmpty ? myStall.name : 'My Stall',
              'category': myStall.category.isNotEmpty ? myStall.category : 'General',
              'is_kyc_approved': true,
              'kyc_status': 'approved',
              'is_open': true,
            }, onConflict: 'stall_holder_id');
            effectiveStallId = fallbackStallId;
          } catch (_) {}
        }

        final isPiece = product.unit.toLowerCase() == 'pc' ||
            product.unit.toLowerCase() == 'piece';
        final categoryTag = _sanitizeCategoryTag(product.category);

        final payload = <String, dynamic>{
          'stall_holder_id': effectiveStallId,
          'product_name': product.name,
          'category_tag': categoryTag,
          'price_per_kg': isPiece ? null : product.price,
          'price_per_piece': isPiece ? product.price : null,
          'unit': isPiece ? 'piece' : 'kg',
          'image_url': product.imageUrl,
          'is_in_stock': product.isActive && product.stockQuantity > 0,
          'is_visible': product.isActive,
          'stock_quantity': product.stockQuantity,
          'description': product.description,
          'discount_percentage': product.discountPercentage,
          'updated_at': DateTime.now().toIso8601String(),
        };

        try {
          var res = await client
              .from('products')
              .update(payload)
              .eq('product_id', product.id)
              .select();

          if (res.isEmpty) {
            res = await client
                .from('products')
                .update(payload)
                .eq('product_name', product.name)
                .eq('stall_holder_id', effectiveStallId)
                .select();
          }

          // If product did not exist in Supabase yet, insert it to sync across devices!
          if (res.isEmpty) {
            final insertPayload = Map<String, dynamic>.from(payload)
              ..['product_id'] = product.id;
            await client.from('products').insert(insertPayload);
          }
        } catch (e) {
          // If column error, retry without unsupported columns
          if (e.toString().contains('stock_quantity') ||
              e.toString().contains('column') ||
              e.toString().contains('discount')) {
            try {
              final fallbackPayload = Map<String, dynamic>.from(payload);
              if (e.toString().contains('stock_quantity')) {
                fallbackPayload.remove('stock_quantity');
              }
              if (e.toString().contains('discount')) {
                fallbackPayload.remove('discount_percentage');
              }
              var res = await client
                  .from('products')
                  .update(fallbackPayload)
                  .eq('product_id', product.id)
                  .select();
              if (res.isEmpty) {
                res = await client
                    .from('products')
                    .update(fallbackPayload)
                    .eq('product_name', product.name)
                    .eq('stall_holder_id', effectiveStallId)
                    .select();
              }
              if (res.isEmpty) {
                final insertPayload = Map<String, dynamic>.from(fallbackPayload)
                  ..['product_id'] = product.id;
                await client.from('products').insert(insertPayload);
              }
            } catch (_) {}
          }
          debugPrint('Error updating product in Supabase: $e');
        }
      } catch (e) {
        debugPrint('Error preparing product update: $e');
      }
    }

    final repository = ref.read(vendorRepositoryProvider);
    await repository.updateVendorProduct(product);
    ref.invalidate(vendorProductsProvider(vendorId));
    ref.invalidate(allProductsProvider);
    ref.invalidate(discountedProductsProvider);
    ref.read(dataRefreshSignal.notifier).notify();
  }

  Future<void> deleteProduct(String productId) async {
    final client = ref.read(supabaseClientProvider);
    if (client != null) {
      try {
        await client.from('products').delete().eq('product_id', productId);
      } catch (e) {
        debugPrint('Error deleting product in Supabase: $e');
      }
    }

    final repository = ref.read(vendorRepositoryProvider);
    await repository.deleteVendorProduct(vendorId, productId);
    ref.invalidate(vendorProductsProvider(vendorId));
    ref.invalidate(allProductsProvider);
    ref.invalidate(discountedProductsProvider);
    ref.read(dataRefreshSignal.notifier).notify();
  }
}

final vendorProductsManagerProvider =
    Provider.family<VendorProductsManager, String>((ref, vendorId) {
      return VendorProductsManager(ref, vendorId);
    });
