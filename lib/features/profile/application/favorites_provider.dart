import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/profile/application/blocked_vendors_provider.dart';

const _kFavoritesKey = 'favorite_vendors';

/// Holds the set of favorite vendor IDs, persisted to SharedPreferences.
class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final ids = prefs.getStringList(_kFavoritesKey) ?? [];
    return ids.toSet();
  }

  void toggle(String vendorId) {
    final Set<String> next;
    if (state.contains(vendorId)) {
      next = {...state}..remove(vendorId);
    } else {
      next = {...state, vendorId};
    }
    state = next;
    _persist(next);
  }

  bool isFavorite(String vendorId) => state.contains(vendorId);

  void _persist(Set<String> ids) {
    ref
        .read(sharedPreferencesProvider)
        .setStringList(_kFavoritesKey, ids.toList());
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);

/// Derives the list of favorited [MarketVendor] objects from the market repo,
/// excluding any blocked vendors.
final favoriteVendorsProvider = Provider<AsyncValue<List<MarketVendor>>>((ref) {
  final favoriteIds = ref.watch(favoritesProvider);
  final blockedIds = ref.watch(blockedVendorsProvider);
  final vendorsAsync = ref.watch(allVendorsProvider);
  return vendorsAsync.whenData((allVendors) {
    return allVendors
        .where((v) => favoriteIds.contains(v.id) && !blockedIds.contains(v.id))
        .toList();
  });
});
