import 'package:flutter/foundation.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/cart/domain/cart_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed [CartRepository] for signed-in users with local fallback.
///
/// The cart lives in a single row `carts/{uid}` with an `items` JSON array.
/// Cart item identity is `(productId, unit)` and quantities sum on add,
/// matching the local and mock repositories.
class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository(this._uid, [this._localFallback]);

  static const _fieldItems = 'items';
  static const _timeout = Duration(seconds: 3);

  final String _uid;
  final CartRepository? _localFallback;

  /// Returns the Supabase client.
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  Future<List<CartItem>> getCartItems() async {
    try {
      final response = await _supabase
          .from('carts')
          .select(_fieldItems)
          .eq('uid', _uid)
          .maybeSingle()
          .timeout(_timeout);

      if (response != null && response[_fieldItems] is List) {
        final items = (response[_fieldItems] as List)
            .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
            .toList();
        if (_localFallback != null) {
          try {
            await _localFallback.replaceAll(items);
          } catch (_) {}
        }
        return items;
      }
    } catch (e) {
      debugPrint('SupabaseCartRepository.getCartItems error: $e');
    }

    if (_localFallback != null) {
      return _localFallback.getCartItems();
    }
    return [];
  }

  @override
  Future<void> addToCart(CartItem item) async {
    // 1. Immediately update local fallback so UI response is instant and durable
    if (_localFallback != null) {
      await _localFallback.addToCart(item);
    }

    // 2. Sync to Supabase
    try {
      final items = _localFallback != null
          ? await _localFallback.getCartItems()
          : [item];
      await _upsertItems(items);
    } catch (e) {
      debugPrint('SupabaseCartRepository.addToCart sync error: $e');
    }
  }

  @override
  Future<void> updateCartItemQuantity({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
    required double quantity,
  }) async {
    if (_localFallback != null) {
      await _localFallback.updateCartItemQuantity(
        productId: productId,
        vendorName: vendorName,
        productName: productName,
        unit: unit,
        quantity: quantity,
      );
    }

    try {
      final items = _localFallback != null
          ? await _localFallback.getCartItems()
          : await getCartItems();
      await _upsertItems(items);
    } catch (e) {
      debugPrint('SupabaseCartRepository.updateCartItemQuantity sync error: $e');
    }
  }

  @override
  Future<void> toggleItemSelection({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) async {
    if (_localFallback != null) {
      await _localFallback.toggleItemSelection(
        productId: productId,
        vendorName: vendorName,
        productName: productName,
        unit: unit,
      );
    }

    try {
      final items = _localFallback != null
          ? await _localFallback.getCartItems()
          : await getCartItems();
      await _upsertItems(items);
    } catch (e) {
      debugPrint('SupabaseCartRepository.toggleItemSelection sync error: $e');
    }
  }

  @override
  Future<void> selectAll(bool value) async {
    if (_localFallback != null) {
      await _localFallback.selectAll(value);
    }

    try {
      final items = _localFallback != null
          ? await _localFallback.getCartItems()
          : await getCartItems();
      await _upsertItems(items);
    } catch (e) {
      debugPrint('SupabaseCartRepository.selectAll sync error: $e');
    }
  }

  @override
  Future<void> selectVendorItems(String vendorName, bool value) async {
    if (_localFallback != null) {
      await _localFallback.selectVendorItems(vendorName, value);
    }

    try {
      final items = _localFallback != null
          ? await _localFallback.getCartItems()
          : await getCartItems();
      await _upsertItems(items);
    } catch (e) {
      debugPrint('SupabaseCartRepository.selectVendorItems sync error: $e');
    }
  }

  @override
  Future<void> removeCartItem({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) async {
    if (_localFallback != null) {
      await _localFallback.removeCartItem(
        productId: productId,
        vendorName: vendorName,
        productName: productName,
        unit: unit,
      );
    }

    try {
      final items = _localFallback != null
          ? await _localFallback.getCartItems()
          : await getCartItems();
      await _upsertItems(items);
    } catch (e) {
      debugPrint('SupabaseCartRepository.removeCartItem sync error: $e');
    }
  }

  @override
  Future<void> removeSelectedItems() async {
    if (_localFallback != null) {
      await _localFallback.removeSelectedItems();
    }

    try {
      final items = _localFallback != null
          ? await _localFallback.getCartItems()
          : await getCartItems();
      await _upsertItems(items);
    } catch (e) {
      debugPrint('SupabaseCartRepository.removeSelectedItems sync error: $e');
    }
  }

  @override
  Future<void> clearCart() async {
    if (_localFallback != null) {
      try {
        await _localFallback.clearCart();
      } catch (_) {}
    }
    try {
      await _supabase
          .from('carts')
          .delete()
          .eq('uid', _uid)
          .timeout(_timeout);
    } catch (e) {
      debugPrint('SupabaseCartRepository.clearCart error: $e');
    }
  }

  @override
  Future<void> replaceAll(List<CartItem> items) async {
    if (_localFallback != null) {
      try {
        await _localFallback.replaceAll(items);
      } catch (_) {}
    }
    await _upsertItems(items, throwOnError: true);
  }

  Future<void> _upsertItems(List<CartItem> items, {bool throwOnError = false}) async {
    if (_localFallback != null) {
      try {
        await _localFallback.replaceAll(items);
      } catch (_) {}
    }
    try {
      await _supabase.from('carts').upsert({
        'uid': _uid,
        _fieldItems: items.map((item) => item.toJson()).toList(),
      }).timeout(_timeout);
    } catch (e) {
      debugPrint('SupabaseCartRepository._upsertItems error: $e');
      if (throwOnError) rethrow;
    }
  }
}