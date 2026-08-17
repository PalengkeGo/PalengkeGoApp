import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/cart/domain/cart_repository.dart';

/// Firestore-backed [CartRepository] for signed-in users.
///
/// The cart lives in a single document `carts/{uid}` with an `items` array.
/// Cart item identity is `(productId, unit)` and quantities sum on add,
/// matching the local and mock repositories.
class FirebaseCartRepository implements CartRepository {
  FirebaseCartRepository(this._firestore, this._uid);

  static const _fieldItems = 'items';

  final FirebaseFirestore _firestore;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _cartDoc =>
      _firestore.collection('carts').doc(_uid);

  @override
  Future<List<CartItem>> getCartItems() async {
    final snapshot = await _cartDoc.get();
    if (!snapshot.exists) {
      return [];
    }
    final items = snapshot.data()?[_fieldItems];
    if (items is! List) {
      return [];
    }
    return items
        .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save(List<CartItem> items) async {
    await _cartDoc.set({
      _fieldItems: items.map((item) => item.toJson()).toList(),
    });
  }

  static bool _sameItem(CartItem a, CartItem b) =>
      a.productId == b.productId && a.unit == b.unit;

  @override
  Future<void> addToCart(CartItem item) async {
    final items = await getCartItems();
    final existingIndex = items.indexWhere((i) => _sameItem(i, item));

    if (existingIndex >= 0) {
      items[existingIndex] = items[existingIndex].copyWith(
        quantity: items[existingIndex].quantity + item.quantity,
        stockQuantity: item.stockQuantity,
      );
    } else {
      items.add(item);
    }
    await _save(items);
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

    if (existingIndex >= 0) {
      if (quantity <= 0) {
        items.removeAt(existingIndex);
      } else {
        items[existingIndex] = items[existingIndex].copyWith(
          quantity: quantity,
        );
      }
      await _save(items);
    }
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
      items[existingIndex] = items[existingIndex].copyWith(
        selected: !items[existingIndex].selected,
      );
      await _save(items);
    }
  }

  @override
  Future<void> selectAll(bool value) async {
    final items = await getCartItems();
    for (var index = 0; index < items.length; index++) {
      items[index] = items[index].copyWith(selected: value);
    }
    await _save(items);
  }

  @override
  Future<void> removeCartItem({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) async {
    final items = await getCartItems();
    items.removeWhere((i) => i.productId == productId && i.unit == unit);
    await _save(items);
  }

  @override
  Future<void> removeSelectedItems() async {
    final items = await getCartItems();
    items.removeWhere((item) => item.selected);
    await _save(items);
  }

  @override
  Future<void> clearCart() async {
    await _cartDoc.delete();
  }

  @override
  Future<void> replaceAll(List<CartItem> items) => _save(items);
}
