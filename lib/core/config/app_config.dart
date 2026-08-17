import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/config/app_environment.dart';

class AppConfig {
  const AppConfig({
    this.environment = AppEnvironment.development,
    this.firebaseEnabled = false,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.paymongoPublicKey = 'pk_test_placeholder',
    this.paymongoBackendUrl = '',
  });

  final AppEnvironment environment;
  final bool firebaseEnabled;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String paymongoPublicKey;

  /// Server endpoint that creates PayMongo payment intents on the app's
  /// behalf. Must point at a backend (Firebase Function / Supabase Edge
  /// Function) — the PayMongo secret key never ships in the app.
  final String paymongoBackendUrl;

  /// Loads configuration from compile-time arguments using `--dart-define`.
  /// Defaults are provided for local development if no flags are passed
  /// (mock repositories, no backend calls).
  factory AppConfig.load() {
    return AppConfig(
      environment: AppEnvironment.fromString(
        const String.fromEnvironment('APP_ENV', defaultValue: 'development'),
      ),
      firebaseEnabled: const bool.fromEnvironment(
        'FIREBASE_ENABLED',
        defaultValue: false, // Default to mock repositories
      ),
      supabaseUrl: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: '',
      ),
      supabaseAnonKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: '',
      ),
      paymongoPublicKey: const String.fromEnvironment(
        'PAYMONGO_PUBLIC_KEY',
        defaultValue: 'pk_test_placeholder', // Placeholder
      ),
      paymongoBackendUrl: const String.fromEnvironment(
        'PAYMONGO_BACKEND_URL',
        defaultValue: '', // Unset until a payment backend exists
      ),
    );
  }

  /// Returns an error message when the configuration cannot support the
  /// requested environment, or `null` when it is valid.
  ///
  /// Local mock mode (no dart-defines) is always valid — only production
  /// (and staging, for the Firebase path) builds demand real credentials.
  /// Production never silently falls back to mock repositories.
  String? validate() {
    if (environment == AppEnvironment.development) {
      return null;
    }

    if (!firebaseEnabled) {
      return 'This ${environment.name} build requires '
          '--dart-define=FIREBASE_ENABLED=true';
    }
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      return 'This ${environment.name} build requires SUPABASE_URL and '
          'SUPABASE_ANON_KEY dart-defines';
    }
    if (environment == AppEnvironment.production &&
        (paymongoPublicKey.isEmpty ||
            paymongoPublicKey == 'pk_test_placeholder')) {
      return 'Production builds require a PayMongo public key via '
          '--dart-define=PAYMONGO_PUBLIC_KEY=...';
    }
    return null;
  }
}

/// A global provider for the AppConfig so it can be read anywhere via Riverpod.
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.load();
});
