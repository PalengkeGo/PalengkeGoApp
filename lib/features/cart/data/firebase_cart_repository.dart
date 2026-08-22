import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/cart/domain/cart_repository.dart';

/// Firestore-backed [CartRepository] for signed-in users.
///
/// The cart lives in a single document `carts/{uid}` with an `items` array.
/// Cart item identity is `(productId, unit)` and quantities sum on add,
/// matching the local and mock repositories.
///
/// Every read-modify-write mutation runs inside ONE Firestore transaction:
/// two devices mutating the same cart concurrently both commit — the old
/// read→mutate→set pattern silently lost the loser's writes.
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
    return _parse(snapshot);
  }

  static List<CartItem> _parse(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return [];
    final items = snap.data()?[_fieldItems];
    if (items is! List) return [];
    return items
        .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Applies [transform] to the cart atomically (read + write in one tx).
  Future<void> _mutate(List<CartItem> Function(List<CartItem>) transform) {
    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(_cartDoc);
      final next = transform(_parse(snap));
      tx.set(_cartDoc, {
        _fieldItems: next.map((item) => item.toJson()).toList(),
      });
    });
  }

  static bool _sameItem(CartItem a, CartItem b) =>
      a.productId == b.productId && a.unit == b.unit;

  @override
  Future<void> addToCart(CartItem item) => _mutate((items) {
        final existingIndex = items.indexWhere((i) => _sameItem(i, item));
        if (existingIndex >= 0) {
          items[existingIndex] = items[existingIndex].copyWith(
            quantity: items[existingIndex].quantity + item.quantity,
            stockQuantity: item.stockQuantity,
          );
        } else {
          items.add(item);
        }
        return items;
      });

  @override
  Future<void> updateCartItemQuantity({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
    required double quantity,
  }) =>
      _mutate((items) {
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
        }
        return items;
      });

  @override
  Future<void> toggleItemSelection({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) =>
      _mutate((items) {
        final existingIndex = items.indexWhere(
          (i) => i.productId == productId && i.unit == unit,
        );
        if (existingIndex >= 0) {
          items[existingIndex] = items[existingIndex].copyWith(
            selected: !items[existingIndex].selected,
          );
        }
        return items;
      });

  @override
  Future<void> selectAll(bool value) => _mutate((items) {
        return [for (final item in items) item.copyWith(selected: value)];
      });

  @override
  Future<void> removeCartItem({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) =>
      _mutate((items) {
        items.removeWhere((i) => i.productId == productId && i.unit == unit);
        return items;
      });

  @override
  Future<void> removeSelectedItems() => _mutate((items) {
        items.removeWhere((item) => item.selected);
        return items;
      });

  @override
  Future<void> clearCart() => _cartDoc.delete();

  @override
  Future<void> replaceAll(List<CartItem> items) => _mutate((_) => items);
}
