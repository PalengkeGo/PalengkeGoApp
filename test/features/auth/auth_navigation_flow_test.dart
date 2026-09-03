import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/login_screen.dart';
import 'package:palengkego/features/auth/presentation/pages/registration_screen.dart';

class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(this.initialUser);

  final AppUser? initialUser;

  @override
  AppUser? build() => initialUser;

  @override
  Future<void> logout() async {
    state = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Navigation & Logout Flow', () {
    testWidgets('LoginScreen to RegistrationScreen preserves back stack and back button returns to Login', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => TestAuthNotifier(null)),
          ],
          child: MaterialApp(
            initialRoute: AppRoutes.login,
            routes: {
              AppRoutes.login: (_) => const LoginScreen(),
              AppRoutes.registration: (_) => const RegistrationScreen(),
              AppRoutes.main: (_) => const Scaffold(body: Text('Main Screen')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);

      // Find Register RichText link and tap
      final registerLink = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Register'),
      );
      expect(registerLink, findsOneWidget);
      await tester.ensureVisible(registerLink);
      await tester.pumpAndSettle();
      await tester.tap(registerLink);
      await tester.pumpAndSettle();

      // Now on RegistrationScreen
      expect(find.byType(RegistrationScreen), findsOneWidget);

      // Tap Back button on RegistrationScreen
      final backButton = find.byKey(const Key('registration_back_button'));
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Successfully returned to LoginScreen without black screen crash!
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('RegistrationScreen standalone back button falls back to LoginScreen if cannot pop', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => TestAuthNotifier(null)),
          ],
          child: MaterialApp(
            initialRoute: AppRoutes.registration,
            routes: {
              AppRoutes.login: (_) => const LoginScreen(),
              AppRoutes.registration: (_) => const RegistrationScreen(),
              AppRoutes.main: (_) => const Scaffold(body: Text('Main Screen')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RegistrationScreen), findsOneWidget);

      // Tap Back button when no previous routes
      final backButton = find.byKey(const Key('registration_back_button'));
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Safely redirected to LoginScreen instead of black screen
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('LoginScreen back button falls back to MainScreen if cannot pop', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => TestAuthNotifier(null)),
          ],
          child: MaterialApp(
            initialRoute: AppRoutes.login,
            routes: {
              AppRoutes.login: (_) => const LoginScreen(),
              AppRoutes.registration: (_) => const RegistrationScreen(),
              AppRoutes.main: (_) => const Scaffold(body: Text('Main Screen')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);

      // Tap Back button on LoginScreen when no previous routes
      final backButton = find.byKey(const Key('login_back_button'));
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Safely redirected to MainScreen
      expect(find.text('Main Screen'), findsOneWidget);
    });

    test('TestAuthNotifier logout properly clears user session to null', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => TestAuthNotifier(MockUsers.customer)),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(authProvider), isNotNull);

      // Execute logout
      await container.read(authProvider.notifier).logout();
      expect(container.read(authProvider), isNull);
    });
  });
}
