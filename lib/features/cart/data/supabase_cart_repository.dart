import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/cart/domain/cart_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed [CartRepository] for signed-in users.
///
/// The cart lives in a single row `carts/{uid}` with an `items` JSON array.
/// Cart item identity is `(productId, unit)` and quantities sum on add,
/// matching the local and mock repositories.
class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository(this._uid);

  static const _fieldItems = 'items';

  final String _uid;

  /// Returns the Supabase client.
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  Future<List<CartItem>> getCartItems() async {
    final response = await _supabase
        .from('carts')
        .select(_fieldItems)
        .eq('uid', _uid)
        .single();

    final items = response[_fieldItems];
    if (items is! List) return [];

    return items
        .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
        .toList();
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
    await _supabase.from('carts').delete().eq('uid', _uid);
  }

  @override
  Future<void> replaceAll(List<CartItem> items) async {
    await _upsertItems(items);
  }

  Future<void> _upsertItems(List<CartItem> items) async {
    await _supabase.from('carts').upsert({
      'uid': _uid,
      _fieldItems: items.map((item) => item.toJson()).toList(),
    });
  }
}