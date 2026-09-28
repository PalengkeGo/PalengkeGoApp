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
  LocalCartRepository(this._prefs, [String storageKey = _defaultStorageKey])
      : _storageKey = storageKey;

  static const _defaultStorageKey = 'local_cart_items_v1';

  final SharedPreferences _prefs;
  final String _storageKey;

  Future<List<CartItem>> _read() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      if (_storageKey == 'device_cart_items_v1') {
        final legacy = _prefs.getString(_defaultStorageKey);
        if (legacy != null && legacy.isNotEmpty) {
          try {
            final decoded = jsonDecode(legacy) as List<dynamic>;
            return decoded
                .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
                .toList();
          } catch (_) {}
        }
      }
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

  static bool _matches(
    CartItem item, {
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) {
    if (productId.isNotEmpty && item.productId.isNotEmpty) {
      if (item.productId == productId && item.unit == unit) {
        if (vendorName.isNotEmpty &&
            item.vendorName.isNotEmpty &&
            item.vendorName.trim().toLowerCase() !=
                vendorName.trim().toLowerCase() &&
            productName.isNotEmpty &&
            item.productName.isNotEmpty &&
            item.productName.trim().toLowerCase() !=
                productName.trim().toLowerCase()) {
          return false;
        }
        return true;
      }
      return false;
    }
    return item.productName.trim().toLowerCase() ==
            productName.trim().toLowerCase() &&
        (vendorName.isEmpty ||
            item.vendorName.trim().toLowerCase() ==
                vendorName.trim().toLowerCase()) &&
        item.unit == unit;
  }

  static bool _sameItem(CartItem a, CartItem b) {
    if (a.productId.isNotEmpty && b.productId.isNotEmpty) {
      if (a.productId == b.productId && a.unit == b.unit) {
        if (a.vendorName.isNotEmpty &&
            b.vendorName.isNotEmpty &&
            a.vendorName.trim().toLowerCase() !=
                b.vendorName.trim().toLowerCase() &&
            a.productName.isNotEmpty &&
            b.productName.isNotEmpty &&
            a.productName.trim().toLowerCase() !=
                b.productName.trim().toLowerCase()) {
          return false;
        }
        return true;
      }
      return false;
    }
    return a.productName.trim().toLowerCase() ==
            b.productName.trim().toLowerCase() &&
        a.vendorName.trim().toLowerCase() ==
            b.vendorName.trim().toLowerCase() &&
        a.unit == b.unit;
  }

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
      (i) => _matches(
        i,
        productId: productId,
        vendorName: vendorName,
        productName: productName,
        unit: unit,
      ),
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
      (i) => _matches(
        i,
        productId: productId,
        vendorName: vendorName,
        productName: productName,
        unit: unit,
      ),
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
  Future<void> selectVendorItems(String vendorName, bool value) async {
    final items = await _read();
    final normVendor = vendorName.trim().toLowerCase();
    for (var index = 0; index < items.length; index++) {
      if (items[index].vendorName.trim().toLowerCase() == normVendor) {
        items[index] = items[index].copyWith(selected: value);
      }
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
    items.removeWhere(
      (i) => _matches(
        i,
        productId: productId,
        vendorName: vendorName,
        productName: productName,
        unit: unit,
      ),
    );
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
    if (_storageKey == 'device_cart_items_v1') {
      await _prefs.remove(_defaultStorageKey);
    }
  }

  @override
  Future<void> replaceAll(List<CartItem> items) => _write(items);
}
