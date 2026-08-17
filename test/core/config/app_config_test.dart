import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/core/config/app_environment.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';

void main() {
  group('AppConfig.load', () {
    test('defaults to local mock mode when no dart-defines are passed', () {
      final config = AppConfig.load();

      expect(config.environment, AppEnvironment.development);
      expect(config.firebaseEnabled, isFalse);
      expect(config.supabaseUrl, isEmpty);
      expect(config.supabaseAnonKey, isEmpty);
      expect(config.paymongoPublicKey, 'pk_test_placeholder');
      expect(config.paymongoBackendUrl, isEmpty);
      expect(config.validate(), isNull);
    });
  });

  group('AppConfig.validate', () {
    test('rejects production without FIREBASE_ENABLED', () {
      const config = AppConfig(environment: AppEnvironment.production);

      expect(config.validate(), contains('FIREBASE_ENABLED'));
    });

    test('rejects production without Supabase credentials', () {
      const config = AppConfig(
        environment: AppEnvironment.production,
        firebaseEnabled: true,
      );

      expect(config.validate(), contains('SUPABASE'));
    });

    test('rejects production with a placeholder PayMongo key', () {
      const config = AppConfig(
        environment: AppEnvironment.production,
        firebaseEnabled: true,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      );

      expect(config.validate(), contains('PAYMONGO_PUBLIC_KEY'));
    });

    test('accepts a fully configured production config', () {
      const config = AppConfig(
        environment: AppEnvironment.production,
        firebaseEnabled: true,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        paymongoPublicKey: 'pk_test_real_key',
      );

      expect(config.validate(), isNull);
    });

    test('staging requires Firebase but tolerates a mock PayMongo key', () {
      const config = AppConfig(
        environment: AppEnvironment.staging,
        firebaseEnabled: true,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      );

      expect(config.validate(), isNull);
    });
  });

  group('firebaseEnabledProvider', () {
    test('mirrors AppConfig.firebaseEnabled', () {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(firebaseEnabled: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(firebaseEnabledProvider), isTrue);
    });
  });

  group('SupabaseService.initialize', () {
    test('throws ArgumentError when credentials are empty', () {
      expect(
        () => SupabaseService.initialize(url: '', anonKey: ''),
        throwsArgumentError,
      );
    });
  });
}
