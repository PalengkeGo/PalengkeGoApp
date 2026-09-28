import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:palengkego/features/market/application/market_provider.dart';

const _kBlockedKey = 'blocked_vendors';

/// Holds the set of blocked vendor IDs, persisted to SharedPreferences.
class BlockedVendorsNotifier extends Notifier<Set<String>> {
  String get _storageKey {
    final uid = ref.watch(authProvider)?.uid;
    if (uid != null && uid.isNotEmpty) {
      return '${_kBlockedKey}_$uid';
    }
    return _kBlockedKey;
  }

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final key = _storageKey;
    final ids = prefs.getStringList(key) ?? [];
    return ids.toSet();
  }

  void block(String vendorId) {
    final next = {...state, vendorId};
    state = next;
    _persist(next);
  }

  void unblock(String vendorId) {
    final next = {...state}..remove(vendorId);
    state = next;
    _persist(next);
  }

  bool isBlocked(String vendorId) => state.contains(vendorId);

  void _persist(Set<String> ids) {
    final uid = ref.read(authProvider)?.uid;
    final key = uid != null && uid.isNotEmpty ? '${_kBlockedKey}_$uid' : _kBlockedKey;
    ref
        .read(sharedPreferencesProvider)
        .setStringList(key, ids.toList());
  }
}

final blockedVendorsProvider =
    NotifierProvider<BlockedVendorsNotifier, Set<String>>(
      BlockedVendorsNotifier.new,
    );

final blockedVendorsListProvider = Provider<AsyncValue<List<MarketVendor>>>((
  ref,
) {
  final blockedIds = ref.watch(blockedVendorsProvider);
  final vendorsAsync = ref.watch(allVendorsProvider);

  if (vendorsAsync.hasValue) {
    final allVendors = vendorsAsync.requireValue;
    final filtered = allVendors.where((v) {
      final idLower = v.id.toLowerCase();
      final nameLower = v.name.toLowerCase();
      return blockedIds.any(
        (b) => b.toLowerCase() == idLower || b.toLowerCase() == nameLower,
      );
    }).toList();
    return AsyncData(filtered);
  }

  return vendorsAsync.whenData((allVendors) {
    return allVendors.where((v) {
      final idLower = v.id.toLowerCase();
      final nameLower = v.name.toLowerCase();
      return blockedIds.any(
        (b) => b.toLowerCase() == idLower || b.toLowerCase() == nameLower,
      );
    }).toList();
  });
});
