import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/preferences_provider.dart';

/// Provider to track if the current user has successfully onboarded as a vendor.
/// This allows the user to switch back to the customer view without losing
/// the "Manage Stall Holder Stall" button.
class HasVendorStallNotifier extends Notifier<bool> {
  static const _key = 'has_vendor_stall';

  @override
  bool build() {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setHasVendorStall(bool value) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(_key, value);
    } catch (_) {
      // Fallback for tests/environments where sharedPreferencesProvider isn't overridden
    }
    state = value;
  }

  Future<void> clear() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.remove(_key);
    } catch (_) {
      // Fallback for tests/environments where sharedPreferencesProvider isn't overridden
    }
    state = false;
  }
}

final hasVendorStallProvider = NotifierProvider<HasVendorStallNotifier, bool>(
  HasVendorStallNotifier.new,
);
