import 'package:palengkego/features/cart/domain/cart_item.dart';

/// Result of merging the signed-out (device) cart into the signed-in
/// (server) cart.
class CartMergeResult {
  const CartMergeResult({required this.items, required this.addedFromDevice});

  final List<CartItem> items;

  /// Number of device-only rows that were newly added to the server cart.
  final int addedFromDevice;
}

/// Merges [deviceCart] into [serverCart] per `docs/cart_merge_rule.md`
/// (Option A).
///
/// Matching key is `(productId, unit)` — different units of the same product
/// never merge. On a match the server row wins for price, stock, image and
/// selection, and quantities are summed. Device-only rows are appended with
/// their own state and counted in [CartMergeResult.addedFromDevice]. Server
/// rows are never dropped.
CartMergeResult mergeCarts({
  required List<CartItem> deviceCart,
  required List<CartItem> serverCart,
}) {
  final merged = <CartItem>[];
  final matchedDevice = <int>{};
  var addedFromDevice = 0;

  for (final serverItem in serverCart) {
    final matchIndex = deviceCart.indexWhere(
      (deviceItem) =>
          deviceItem.productId == serverItem.productId &&
          deviceItem.unit == serverItem.unit,
    );
    if (matchIndex >= 0) {
      matchedDevice.add(matchIndex);
      merged.add(
        serverItem.copyWith(
          quantity: serverItem.quantity + deviceCart[matchIndex].quantity,
        ),
      );
    } else {
      merged.add(serverItem);
    }
  }

  for (var index = 0; index < deviceCart.length; index++) {
    if (!matchedDevice.contains(index)) {
      merged.add(deviceCart[index]);
      addedFromDevice++;
    }
  }

  return CartMergeResult(items: merged, addedFromDevice: addedFromDevice);
}
