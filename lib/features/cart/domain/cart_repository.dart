import 'package:palengkego/features/cart/domain/cart_item.dart';

abstract class CartRepository {
  /// Fetches the user's current cart items
  Future<List<CartItem>> getCartItems();

  /// Adds a new item to the cart or increases the quantity if it already exists
  Future<void> addToCart(CartItem item);

  /// Updates the quantity of a specific item
  Future<void> updateCartItemQuantity({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
    required double quantity,
  });

  /// Toggles the selected state for checkout of a specific item
  Future<void> toggleItemSelection({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  });

  /// Sets the selected state for all items
  Future<void> selectAll(bool value);

  /// Removes a specific item from the cart entirely
  Future<void> removeCartItem({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  });

  /// Removes all currently selected items from the cart
  Future<void> removeSelectedItems();

  /// Clears all items from the cart
  Future<void> clearCart();

  /// Replaces the entire cart with [items] (used by guest-cart merge).
  Future<void> replaceAll(List<CartItem> items);
}
