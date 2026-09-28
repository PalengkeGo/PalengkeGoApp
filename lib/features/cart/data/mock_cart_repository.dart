import 'package:flutter/foundation.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/cart/domain/cart_repository.dart';

/// In-memory [CartRepository] used by tests and mock mode.
///
/// Cart item identity is `(productId, unit)` — the same key the local and
/// Firestore repositories use, so the contract stays identical across
/// implementations.
class MockCartRepository implements CartRepository {
  static final List<CartItem> _items = [];

  @visibleForTesting
  static void clearTestState() {
    _items.clear();
  }

  @visibleForTesting
  List<CartItem> get items => List.unmodifiable(_items);

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
  Future<List<CartItem>> getCartItems() async {
    return List.unmodifiable(_items);
  }

  @override
  Future<void> addToCart(CartItem item) async {
    final existingIndex = _items.indexWhere((i) => _sameItem(i, item));

    if (existingIndex >= 0) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + item.quantity,
        stockQuantity: item.stockQuantity,
      );
    } else {
      _items.add(item);
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
    final existingIndex = _items.indexWhere(
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
        _items.removeAt(existingIndex);
      } else {
        _items[existingIndex] = _items[existingIndex].copyWith(
          quantity: quantity,
        );
      }
    }
  }

  @override
  Future<void> toggleItemSelection({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) async {
    final existingIndex = _items.indexWhere(
      (i) => _matches(
        i,
        productId: productId,
        vendorName: vendorName,
        productName: productName,
        unit: unit,
      ),
    );

    if (existingIndex >= 0) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        selected: !_items[existingIndex].selected,
      );
    }
  }

  @override
  Future<void> selectAll(bool value) async {
    for (var index = 0; index < _items.length; index++) {
      _items[index] = _items[index].copyWith(selected: value);
    }
  }

  @override
  Future<void> selectVendorItems(String vendorName, bool value) async {
    final normVendor = vendorName.trim().toLowerCase();
    for (var index = 0; index < _items.length; index++) {
      if (_items[index].vendorName.trim().toLowerCase() == normVendor) {
        _items[index] = _items[index].copyWith(selected: value);
      }
    }
  }

  @override
  Future<void> removeCartItem({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) async {
    _items.removeWhere(
      (i) => _matches(
        i,
        productId: productId,
        vendorName: vendorName,
        productName: productName,
        unit: unit,
      ),
    );
  }

  @override
  Future<void> removeSelectedItems() async {
    _items.removeWhere((item) => item.selected);
  }

  @override
  Future<void> clearCart() async {
    _items.clear();
  }

  @override
  Future<void> replaceAll(List<CartItem> items) async {
    _items
      ..clear()
      ..addAll(items);
  }
}
