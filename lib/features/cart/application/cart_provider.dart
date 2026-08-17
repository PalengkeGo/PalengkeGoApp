import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/cart/application/cart_merger.dart';
import 'package:palengkego/features/cart/data/firebase_cart_repository.dart';
import 'package:palengkego/features/cart/data/local_cart_repository.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/cart/domain/cart_repository.dart';

/// Single explicit backend switch for the cart.
///
/// Firebase mode with a signed-in user reads/writes `carts/{uid}` in
/// Firestore; everything else falls back to the SharedPreferences-backed
/// device cart. Tests override this provider directly.
final cartRepositoryProvider = Provider<CartRepository>((ref) {
  if (ref.watch(firebaseEnabledProvider)) {
    final uid = ref.watch(authProvider)?.uid;
    if (uid != null && uid.isNotEmpty) {
      return FirebaseCartRepository(ref.watch(firestoreProvider), uid);
    }
  }
  return LocalCartRepository(ref.watch(sharedPreferencesProvider));
});

class CartNotifier extends AsyncNotifier<List<CartItem>> {
  @override
  Future<List<CartItem>> build() async {
    final repository = ref.read(cartRepositoryProvider);
    await _mergeDeviceCartIfAny(repository);
    return repository.getCartItems();
  }

  /// Merges the signed-out device cart into the signed-in server cart once,
  /// per `docs/cart_merge_rule.md`. The device cart is cleared only after the
  /// merge write succeeds, so a failed merge leaves it in place for the next
  /// login; checkout cannot start until this resolves because the cart does
  /// not load until the merge finishes.
  Future<void> _mergeDeviceCartIfAny(CartRepository repository) async {
    if (repository is! FirebaseCartRepository) {
      return;
    }
    final localRepo = LocalCartRepository(ref.read(sharedPreferencesProvider));
    final deviceCart = await localRepo.getCartItems();
    if (deviceCart.isEmpty) {
      return;
    }

    try {
      final serverCart = await repository.getCartItems();
      final result = mergeCarts(deviceCart: deviceCart, serverCart: serverCart);
      await repository.replaceAll(result.items);
      await localRepo.clearCart();
      AppServices.showSnackBar(
        result.addedFromDevice > 0
            ? 'Cart merged with your account — '
                  '${result.addedFromDevice} item'
                  '${result.addedFromDevice == 1 ? '' : 's'} added from this device'
            : 'Cart merged with your account',
      );
    } catch (_) {
      // Keep the device cart intact; the merge retries on the next login.
    }
  }

  Future<void> addToCart(CartItem item) async {
    final repository = ref.read(cartRepositoryProvider);
    await repository.addToCart(item);
    ref.invalidateSelf();
  }

  Future<void> updateQuantity(
    String productId,
    String vendorName,
    String productName,
    String unit,
    double quantity,
  ) async {
    final repository = ref.read(cartRepositoryProvider);
    await repository.updateCartItemQuantity(
      productId: productId,
      vendorName: vendorName,
      productName: productName,
      unit: unit,
      quantity: quantity,
    );
    ref.invalidateSelf();
  }

  Future<void> toggleSelect(
    String productId,
    String vendorName,
    String productName,
    String unit,
  ) async {
    final repository = ref.read(cartRepositoryProvider);
    await repository.toggleItemSelection(
      productId: productId,
      vendorName: vendorName,
      productName: productName,
      unit: unit,
    );
    ref.invalidateSelf();
  }

  Future<void> selectAll(bool value) async {
    final repository = ref.read(cartRepositoryProvider);
    await repository.selectAll(value);
    ref.invalidateSelf();
  }

  Future<void> removeItem(
    String productId,
    String vendorName,
    String productName,
    String unit,
  ) async {
    final repository = ref.read(cartRepositoryProvider);
    await repository.removeCartItem(
      productId: productId,
      vendorName: vendorName,
      productName: productName,
      unit: unit,
    );
    ref.invalidateSelf();
  }

  Future<void> removeSelectedItems() async {
    final repository = ref.read(cartRepositoryProvider);
    await repository.removeSelectedItems();
    ref.invalidateSelf();
  }

  Future<void> clearCart() async {
    final repository = ref.read(cartRepositoryProvider);
    await repository.clearCart();
    ref.invalidateSelf();
  }
}

final cartItemsProvider = AsyncNotifierProvider<CartNotifier, List<CartItem>>(
  () {
    return CartNotifier();
  },
);

final cartCountProvider = Provider<AsyncValue<int>>((ref) {
  final cartItemsAsync = ref.watch(cartItemsProvider);
  return cartItemsAsync.whenData((cartItems) {
    return cartItems.length;
  });
});

final cartSubtotalProvider = Provider<AsyncValue<double>>((ref) {
  final cartItemsAsync = ref.watch(cartItemsProvider);
  return cartItemsAsync.whenData((cartItems) {
    return cartItems
        .where((item) => item.selected)
        .fold<double>(0, (sum, item) => sum + item.total);
  });
});
