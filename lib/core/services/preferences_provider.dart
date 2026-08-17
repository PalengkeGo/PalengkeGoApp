import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exposes the pre-initialized [SharedPreferences] instance.
/// Override this in [ProviderScope] by calling
/// `SharedPreferences.getInstance()` before `runApp`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope '
    'with an initialized SharedPreferences instance.',
  ),
);
