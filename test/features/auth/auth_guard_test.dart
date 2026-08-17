import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';

class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(this.initialUser);

  final AppUser? initialUser;

  @override
  AppUser? build() => initialUser;
}

void main() {
  Widget buildGuardedApp(AppUser? user) {
    return ProviderScope(
      overrides: [authProvider.overrideWith(() => TestAuthNotifier(user))],
      child: const MaterialApp(
        home: AuthGuard(child: Scaffold(body: Text('Protected content'))),
      ),
    );
  }

  Widget buildGuardedAppWithRoutes(AppUser? user) {
    return ProviderScope(
      overrides: [authProvider.overrideWith(() => TestAuthNotifier(user))],
      child: MaterialApp(
        home: const AuthGuard(child: Scaffold(body: Text('Protected content'))),
        routes: {
          '/login': (_) => const Scaffold(body: Text('Login route')),
          '/registration': (_) =>
              const Scaffold(body: Text('Registration route')),
        },
      ),
    );
  }

  Widget buildVendorGuardedApp(AppUser? user) {
    return ProviderScope(
      overrides: [authProvider.overrideWith(() => TestAuthNotifier(user))],
      child: const MaterialApp(
        home: AuthGuard(
          allowedRoles: {UserRole.vendor},
          child: Scaffold(body: Text('Vendor content')),
        ),
      ),
    );
  }

  group('AuthGuard', () {
    testWidgets(
      'renders account required screen when no user is authenticated',
      (tester) async {
        await tester.pumpWidget(buildGuardedApp(null));

        expect(find.text('Account Required'), findsOneWidget);
        expect(find.text('Protected content'), findsNothing);
      },
    );

    testWidgets('renders protected child when a user is authenticated', (
      tester,
    ) async {
      await tester.pumpWidget(buildGuardedApp(MockUsers.customer));

      expect(find.text('Protected content'), findsOneWidget);
      expect(find.text('Account Required'), findsNothing);
    });

    testWidgets('login and register buttons navigate to auth routes', (
      tester,
    ) async {
      await tester.pumpWidget(buildGuardedAppWithRoutes(null));

      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
      expect(find.text('Login route'), findsOneWidget);

      Navigator.of(tester.element(find.text('Login route'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.text('Registration route'), findsOneWidget);
    });

    testWidgets('renders role restricted screen for non-vendor users', (
      tester,
    ) async {
      await tester.pumpWidget(buildVendorGuardedApp(MockUsers.customer));

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.text('Vendor content'), findsNothing);
    });

    testWidgets('renders vendor content for vendor users', (tester) async {
      await tester.pumpWidget(buildVendorGuardedApp(MockUsers.vendor));

      expect(find.text('Vendor content'), findsOneWidget);
      expect(find.text('Access Restricted'), findsNothing);
    });
  });
}
