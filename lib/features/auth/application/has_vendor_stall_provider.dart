import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to track if the current user has successfully onboarded as a vendor.
/// This allows the user to switch back to the customer view without losing
/// the "Manage Stall Holder Stall" button.
class HasVendorStallNotifier extends Notifier<bool> {
  static const _key = 'has_vendor_stall';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> setHasVendorStall(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    state = value;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = false;
  }
}

final hasVendorStallProvider = NotifierProvider<HasVendorStallNotifier, bool>(
  HasVendorStallNotifier.new,
);
