import 'dart:convert';

import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/cart/domain/cart_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed [CartRepository] for signed-out (device) users.
///
/// Semantics mirror [MockCartRepository] exactly — cart item identity is
/// `(productId, unit)` and quantities sum on add — so the cart contract is
/// identical in mock, device and Firestore modes.
class LocalCartRepository implements CartRepository {
  LocalCartRepository(this._prefs);

  static const _storageKey = 'local_cart_items_v1';

  final SharedPreferences _prefs;

  Future<List<CartItem>> _read() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _write(List<CartItem> items) async {
    final encoded = jsonEncode(items.map((item) => item.toJson()).toList());
    await _prefs.setString(_storageKey, encoded);
  }

  static bool _sameItem(CartItem a, CartItem b) =>
      a.productId == b.productId && a.unit == b.unit;

  @override
  Future<List<CartItem>> getCartItems() => _read();

  @override
  Future<void> addToCart(CartItem item) async {
    final items = await _read();
    final existingIndex = items.indexWhere((i) => _sameItem(i, item));

    if (existingIndex >= 0) {
      items[existingIndex] = items[existingIndex].copyWith(
        quantity: items[existingIndex].quantity + item.quantity,
        stockQuantity: item.stockQuantity,
      );
    } else {
      items.add(item);
    }
    await _write(items);
  }

  @override
  Future<void> updateCartItemQuantity({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
    required double quantity,
  }) async {
    final items = await _read();
    final existingIndex = items.indexWhere(
      (i) => i.productId == productId && i.unit == unit,
    );

    if (existingIndex >= 0) {
      if (quantity <= 0) {
        items.removeAt(existingIndex);
      } else {
        items[existingIndex] = items[existingIndex].copyWith(
          quantity: quantity,
        );
      }
      await _write(items);
    }
  }

  @override
  Future<void> toggleItemSelection({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) async {
    final items = await _read();
    final existingIndex = items.indexWhere(
      (i) => i.productId == productId && i.unit == unit,
    );

    if (existingIndex >= 0) {
      items[existingIndex] = items[existingIndex].copyWith(
        selected: !items[existingIndex].selected,
      );
      await _write(items);
    }
  }

  @override
  Future<void> selectAll(bool value) async {
    final items = await _read();
    for (var index = 0; index < items.length; index++) {
      items[index] = items[index].copyWith(selected: value);
    }
    await _write(items);
  }

  @override
  Future<void> removeCartItem({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) async {
    final items = await _read();
    items.removeWhere((i) => i.productId == productId && i.unit == unit);
    await _write(items);
  }

  @override
  Future<void> removeSelectedItems() async {
    final items = await _read();
    items.removeWhere((item) => item.selected);
    await _write(items);
  }

  @override
  Future<void> clearCart() async {
    await _prefs.remove(_storageKey);
  }

  @override
  Future<void> replaceAll(List<CartItem> items) => _write(items);
}
