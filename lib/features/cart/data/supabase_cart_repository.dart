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
  SupabaseCartRepository(
    this._uid, [
    this._localFallback,
    SupabaseClient? client,
  ]) : _client = client;

  static const _fieldItems = 'items';
  static const _timeout = Duration(seconds: 3);

  final String _uid;
  final CartRepository? _localFallback;
  final SupabaseClient? _client;

  /// Returns the Supabase client.
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<List<CartItem>> getCartItems() async {
    try {
      final items = await _fetchRemoteItems();
      await _localFallback?.replaceAll(items);
      return items;
    } catch (e) {
      debugPrint('SupabaseCartRepository.getCartItems error: $e');
    }

    if (_localFallback != null) {
      return _localFallback.getCartItems();
    }
    return [];
  }

  @override
  Future<void> addToCart(CartItem item) async {
    await _mutateLocalAndSync(() => _localFallback!.addToCart(item));
  }

  @override
  Future<void> updateCartItemQuantity({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
    required double quantity,
  }) async {
    await _mutateLocalAndSync(
      () => _localFallback!.updateCartItemQuantity(
        productId: productId,
        vendorName: vendorName,
        productName: productName,
        unit: unit,
        quantity: quantity,
      ),
    );
  }

  @override
  Future<void> toggleItemSelection({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) async {
    await _mutateLocalAndSync(
      () => _localFallback!.toggleItemSelection(
        productId: productId,
        vendorName: vendorName,
        productName: productName,
        unit: unit,
      ),
    );
  }

  @override
  Future<void> selectAll(bool value) async {
    await _mutateLocalAndSync(() => _localFallback!.selectAll(value));
  }

  @override
  Future<void> selectVendorItems(String vendorName, bool value) async {
    await _mutateLocalAndSync(
      () => _localFallback!.selectVendorItems(vendorName, value),
    );
  }

  @override
  Future<void> removeCartItem({
    required String productId,
    required String vendorName,
    required String productName,
    required String unit,
  }) async {
    await _mutateLocalAndSync(
      () => _localFallback!.removeCartItem(
        productId: productId,
        vendorName: vendorName,
        productName: productName,
        unit: unit,
      ),
    );
  }

  @override
  Future<void> removeSelectedItems() async {
    await _mutateLocalAndSync(() => _localFallback!.removeSelectedItems());
  }

  @override
  Future<void> clearCart() async {
    await _supabase.from('carts').delete().eq('uid', _uid).timeout(_timeout);
    await _localFallback?.clearCart();
  }

  @override
  Future<void> replaceAll(List<CartItem> items) async {
    await _upsertItems(items);
  }

  Future<void> _mutateLocalAndSync(Future<void> Function() mutate) async {
    final fallback = _localFallback;
    if (fallback == null) {
      throw StateError('Cart update requires an existing local cart mirror.');
    }

    final previous = await fallback.getCartItems();
    try {
      await fallback.replaceAll(await _fetchRemoteItems());
      await mutate();
      await _upsertItems(await fallback.getCartItems());
    } catch (_) {
      await fallback.replaceAll(previous);
      rethrow;
    }
  }

  Future<List<CartItem>> _fetchRemoteItems() async {
    final response = await _supabase
        .from('carts')
        .select(_fieldItems)
        .eq('uid', _uid)
        .maybeSingle()
        .timeout(_timeout);
    final rawItems = response?[_fieldItems];
    if (rawItems is! List) return [];
    return rawItems
        .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _upsertItems(List<CartItem> items) async {
    try {
      await _supabase
          .from('carts')
          .upsert({
            'uid': _uid,
            _fieldItems: items.map((item) => item.toJson()).toList(),
          })
          .timeout(_timeout);
      await _localFallback?.replaceAll(items);
    } catch (e) {
      debugPrint('SupabaseCartRepository._upsertItems error: $e');
      rethrow;
    }
  }
}
