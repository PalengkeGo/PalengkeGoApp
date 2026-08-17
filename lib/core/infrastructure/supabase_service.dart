import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// True when Supabase credentials were supplied via dart-defines, matching
/// the exact condition `main.dart` uses before calling
/// [SupabaseService.initialize]. Guards [supabaseClientProvider] so it is
/// only ever touched after successful initialization.
final supabaseConfiguredProvider = Provider<bool>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.supabaseUrl.isNotEmpty && config.supabaseAnonKey.isNotEmpty;
});

/// Provider for the Supabase Client, used primarily for the recipes backend
/// and recommendation engine.
///
/// Returns null when Supabase was never initialized (no URL/anon-key
/// dart-defines), so consumers can treat it as "not configured" instead of
/// crashing on an uninitialized singleton.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return Supabase.instance.client;
});

/// Service class to handle Supabase initialization.
class SupabaseService {
  /// Initializes the Supabase client using credentials from [AppConfig]
  /// (passed as [url] and [anonKey] from `--dart-define` values).
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    if (url.isEmpty || anonKey.isEmpty) {
      throw ArgumentError('Supabase url and anon key must be provided');
    }

    await Supabase.initialize(url: url, publishableKey: anonKey);
  }
}
