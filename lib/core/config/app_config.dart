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
    this.googleServerClientId =
        '817586589237-g2ghn8agsgae7h2pcu6scdic65s8l110.apps.googleusercontent.com',
  });

  final AppEnvironment environment;
  final bool firebaseEnabled;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String paymongoPublicKey;
  final String googleServerClientId;

  /// Server endpoint that creates PayMongo payment intents on the app's
  /// behalf. Must point at a backend (Firebase Function / Supabase Edge
  /// Function) — the PayMongo secret key never ships in the app.
  final String paymongoBackendUrl;

  /// Loads configuration from compile-time arguments using `--dart-define`.
  /// Defaults are provided for local development if no flags are passed
  /// (mock repositories, no backend calls).
  factory AppConfig.load() {
    var paymongoKey = const String.fromEnvironment('PAYMONGO_PUBLIC_KEY');
    const rawAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    // Auto-recover if CLI arguments accidentally merged into SUPABASE_ANON_KEY
    if ((paymongoKey.isEmpty || paymongoKey == 'pk_test_placeholder') &&
        rawAnonKey.contains('PAYMONGO_PUBLIC_KEY=')) {
      final match = RegExp(r'PAYMONGO_PUBLIC_KEY=([^\s\\`]+)').firstMatch(rawAnonKey);
      if (match != null) {
        paymongoKey = match.group(1) ?? paymongoKey;
      }
    }

    final hasPaymongoKey =
        paymongoKey.isNotEmpty && paymongoKey != 'pk_test_placeholder';
    final hasBackendFlag = const bool.fromEnvironment(
          'FIREBASE_ENABLED',
          defaultValue: false,
        ) ||
        hasPaymongoKey ||
        const String.fromEnvironment('SUPABASE_URL').isNotEmpty;

    // Check if the provided SUPABASE_ANON_KEY is a valid JWT (3 dot-separated parts)
    final isAnonKeyValidJwt = rawAnonKey.isNotEmpty &&
        rawAnonKey.split('.').length == 3 &&
        !rawAnonKey.contains('--dart-define');

    return AppConfig(
      environment: AppEnvironment.fromString(
        const String.fromEnvironment('APP_ENV', defaultValue: 'development'),
      ),
      firebaseEnabled: const bool.fromEnvironment(
            'FIREBASE_ENABLED',
            defaultValue: false, // Default to mock repositories
          ) ||
          hasPaymongoKey,
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL').isNotEmpty
          ? const String.fromEnvironment('SUPABASE_URL')
          : (hasBackendFlag
              ? 'https://jvpplxlcucuzmbtbmtah.supabase.co'
              : ''),
      supabaseAnonKey: isAnonKeyValidJwt
          ? rawAnonKey
          : (hasBackendFlag
              ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2cHBseGxjdWN1em1idGJtdGFoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxMjIyNTUsImV4cCI6MjEwMjY5ODI1NX0.FrYvHhZjARj-XZNC1ZgxfVa1ixJQsuMTkRRMTxCamw0'
              : ''),
      paymongoPublicKey: paymongoKey.isNotEmpty
          ? paymongoKey
          : 'pk_test_placeholder',
      paymongoBackendUrl: const String.fromEnvironment(
        'PAYMONGO_BACKEND_URL',
        defaultValue: '', // Unset until a payment backend exists
      ),
      googleServerClientId: const String.fromEnvironment(
        'GOOGLE_SERVER_CLIENT_ID',
        defaultValue:
            '817586589237-g2ghn8agsgae7h2pcu6scdic65s8l110.apps.googleusercontent.com',
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
