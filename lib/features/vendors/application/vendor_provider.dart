import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/data/mock_vendor_repository.dart';
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
  // 1. Check if vendor matches currently active logged-in vendor stall
  final myStall = ref.watch(vendorStallProvider);
  if (vendorId == myStall.stallId || vendorId == myStall.ownerUid) {
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
      rating: myStall.totalRatings > 0 ? myStall.averageRating : 0.0,
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

  // 2. Check Supabase stall_holders if connected
  final supabase = ref.watch(supabaseClientProvider);
  if (supabase != null) {
    try {
      final res = await supabase
          .from('stall_holders')
          .select()
          .or('stall_holder_id.eq.$vendorId,user_id.eq.$vendorId')
          .maybeSingle();

      if (res != null) {
        final stallNum = res['stall_number']?.toString();
        final floorNum = res['floor_number']?.toString();
        final section = res['section']?.toString();
        final category = res['category'] as String? ?? 'Fruits';

        String stallLoc = 'Market Stall';
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

        final banner = res['banner_image_url'] as String?;
        final avatar = res['avatar_image_url'] as String?;
        final desc = res['description'] as String?;

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

        return VendorProfile(
          id: res['stall_holder_id'] as String? ?? vendorId,
          name: res['stall_name'] as String? ?? 'Stall Holder',
          category: category,
          rating: (res['rating'] as num?)?.toDouble() ?? 0.0,
          reviewCount: (res['review_count'] as num?)?.toInt() ?? 0,
          isOpen: res['is_open'] as bool? ?? true,
          stallLocation: stallLoc,
          imageUrl: (banner != null && banner.isNotEmpty)
              ? banner
              : (category.toLowerCase().contains('fruit')
                  ? 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?auto=format&fit=crop&q=80&w=800'
                  : 'assets/images/ncpm-onboarding.jpg'),
          avatarUrl: avatar ?? '',
          phoneNumber: phone,
          description: (desc != null && desc.isNotEmpty)
              ? desc
              : 'Fresh $category directly to your doorstep. Quality and freshness guaranteed!',
        );
      }
    } catch (_) {}
  }

  // 3. Fallback to repository
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
          final stallRes = await supabase
              .from('stall_holders')
              .select('stall_holder_id')
              .or('stall_holder_id.eq.$vendorId,user_id.eq.$vendorId')
              .maybeSingle();
          if (stallRes != null && stallRes['stall_holder_id'] != null) {
            targetStallId = stallRes['stall_holder_id'].toString();
          }

          final rows = await supabase
              .from('products')
              .select()
              .or('stall_holder_id.eq.$targetStallId,stall_holder_id.eq.$vendorId');

          if (rows is List && rows.isNotEmpty) {
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
              final stock = (row['stock_quantity'] as num?)?.toDouble() ??
                  (inStock ? 15.0 : 0.0);

              final p = VendorProduct(
                id: row['product_id']?.toString() ?? '',
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
                imageUrl: row['image_url'] as String? ?? '',
                isActive: inStock,
                stockQuantity: stock,
                discountPercentage:
                    (row['discount_percentage'] as num?)?.toDouble(),
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
      for (final p in local) {
        final normName = p.name.toLowerCase().trim();
        if (!seenIds.contains(p.id) && !seenNames.contains(normName)) {
          combined.add(p);
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
        };

        if (_uuidPattern.hasMatch(product.id)) {
          payload['product_id'] = product.id;
        }

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
        debugPrint('Error inserting product into Supabase: $e');
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
    ref.read(dataRefreshSignal.notifier).notify();
  }

  Future<void> updateProduct(VendorProduct product) async {
    final client = ref.read(supabaseClientProvider);
    if (client != null) {
      try {
        final isPiece = product.unit.toLowerCase() == 'pc' ||
            product.unit.toLowerCase() == 'piece';
        final categoryTag = _sanitizeCategoryTag(product.category);

        final payload = <String, dynamic>{
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
          'updated_at': DateTime.now().toIso8601String(),
        };

        await client
            .from('products')
            .update(payload)
            .eq('product_id', product.id);
      } catch (e) {
        debugPrint('Error updating product in Supabase: $e');
      }
    }

    final repository = ref.read(vendorRepositoryProvider);
    await repository.updateVendorProduct(product);
    ref.invalidate(vendorProductsProvider(vendorId));
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
    ref.read(dataRefreshSignal.notifier).notify();
  }
}

final vendorProductsManagerProvider =
    Provider.family<VendorProductsManager, String>((ref, vendorId) {
      return VendorProductsManager(ref, vendorId);
    });
