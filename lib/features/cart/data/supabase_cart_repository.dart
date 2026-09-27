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
          .maybeSingle();

      if (response != null && response[_fieldItems] is List) {
        final items = (response[_fieldItems] as List)
            .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
            .toList();
        if (_localFallback != null) {
          try {
            await _localFallback!.replaceAll(items);
          } catch (_) {}
        }
        return items;
      }
    } catch (e) {
      debugPrint('SupabaseCartRepository.getCartItems error: $e');
    }

    if (_localFallback != null) {
      return _localFallback!.getCartItems();
    }
    return [];
  }

  @override
  Future<void> addToCart(CartItem item) async {
    final items = await getCartItems();
    final existingIndex = items.indexWhere(
      (i) => i.productId == item.productId && i.unit == item.unit,
    );

    List<CartItem> next;
    if (existingIndex >= 0) {
      next = List.of(items);
      next[existingIndex] = next[existingIndex].copyWith(
        quantity: next[existingIndex].quantity + item.quantity,
        stockQuantity: item.stockQuantity,
      );
    } else {
      next = [...items, item];
    }

    if (_localFallback != null) {
      try {
        await _localFallback!.addToCart(item);
      } catch (_) {}
    }

    await _upsertItems(next);
  }

  @override
  Future<void> updateCartItemQuantity({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
    required double quantity,
  }) async {
    final items = await getCartItems();
    final existingIndex = items.indexWhere(
      (i) => i.productId == productId && i.unit == unit,
    );

    List<CartItem> next;
    if (existingIndex >= 0) {
      next = List.of(items);
      if (quantity <= 0) {
        next.removeAt(existingIndex);
      } else {
        next[existingIndex] = next[existingIndex].copyWith(
          quantity: quantity,
        );
      }
    } else {
      return;
    }

    await _upsertItems(next);
  }

  @override
  Future<void> toggleItemSelection({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) async {
    final items = await getCartItems();
    final existingIndex = items.indexWhere(
      (i) => i.productId == productId && i.unit == unit,
    );

    if (existingIndex >= 0) {
      final next = List.of(items);
      next[existingIndex] = next[existingIndex].copyWith(
        selected: !next[existingIndex].selected,
      );
      await _upsertItems(next);
    }
  }

  @override
  Future<void> selectAll(bool value) async {
    final items = await getCartItems();
    final next = items.map((item) => item.copyWith(selected: value)).toList();
    await _upsertItems(next);
  }

  @override
  Future<void> removeCartItem({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) async {
    final items = await getCartItems();
    final next = items
        .where((i) => !(i.productId == productId && i.unit == unit))
        .toList();
    await _upsertItems(next);
  }

  @override
  Future<void> removeSelectedItems() async {
    final items = await getCartItems();
    final next = items.where((item) => !item.selected).toList();
    await _upsertItems(next);
  }

  @override
  Future<void> clearCart() async {
    if (_localFallback != null) {
      try {
        await _localFallback!.clearCart();
      } catch (_) {}
    }
    try {
      await _supabase.from('carts').delete().eq('uid', _uid);
    } catch (e) {
      debugPrint('SupabaseCartRepository.clearCart error: $e');
    }
  }

  @override
  Future<void> replaceAll(List<CartItem> items) async {
    if (_localFallback != null) {
      try {
        await _localFallback!.replaceAll(items);
      } catch (_) {}
    }
    await _upsertItems(items);
  }

  Future<void> _upsertItems(List<CartItem> items) async {
    if (_localFallback != null) {
      try {
        await _localFallback!.replaceAll(items);
      } catch (_) {}
    }
    try {
      await _supabase.from('carts').upsert({
        'uid': _uid,
        _fieldItems: items.map((item) => item.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('SupabaseCartRepository._upsertItems error: $e');
    }
  }
}