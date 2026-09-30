import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/home/application/search_provider.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/profile/application/blocked_vendors_provider.dart';
import 'package:palengkego/features/profile/application/favorites_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_reviews_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_stall_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

SupabaseClient _clientFor(
  Future<http.Response> Function(http.Request) handler,
) => SupabaseClient(
  'https://example.supabase.co',
  'test-key',
  httpClient: MockClient((request) async {
    final response = await handler(request);
    return http.Response.bytes(
      response.bodyBytes,
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }),
);

class _VendorUser extends AuthNotifier {
  @override
  AppUser? build() => const AppUser(
    uid: 'vendor',
    displayName: 'Britanico Store',
    email: 'v@example.com',
    role: UserRole.vendor,
  );
}

class _TokenUser extends Fake implements User {
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token';
}

class _FirebaseAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _TokenUser();
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

/// Keeps the market catalog providers alive, as the Home screen does.
class _CatalogHost extends ConsumerWidget {
  const _CatalogHost({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(allVendorsProvider);
    ref.watch(popularVendorsProvider);
    ref.watch(vendorsByCategoryProvider('Vegetables'));
    return child;
  }
}

void main() {
  test('saving a stall category over Supabase does not trip a cycle', () async {
    final prefs = await _prefs();
    final client = _clientFor((request) async {
      if (request.url.path.endsWith('save-stall')) return _json({});
      if (request.url.path.endsWith('stall_holder_schedule')) {
        return _json([
          {'day_of_week': 'Monday'},
        ]);
      }
      if (request.url.path.endsWith('stall_holders')) {
        final wantsSingle = (request.headers['accept'] ?? '').contains('object');
        return wantsSingle
            ? _json({'stall_holder_id': 'vendor', 'stall_name': 'Store'})
            : _json(<Object>[]);
      }
      return _json(<Object>[]);
    });
    addTearDown(client.dispose);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(client),
        firebaseAuthProvider.overrideWithValue(_FirebaseAuth()),
        authProvider.overrideWith(_VendorUser.new),
      ],
    );
    addTearDown(container.dispose);

    container.listen(allVendorsProvider, (_, _) {});
    container.listen(allProductsProvider, (_, _) {});
    container.listen(popularVendorsProvider, (_, _) {});
    container.listen(vendorsByCategoryProvider('Vegetables'), (_, _) {});
    container.listen(vendorProfileProvider('vendor'), (_, _) {});
    container.listen(filteredVendorsProvider('Vegetables'), (_, _) {});
    container.listen(favoriteVendorsProvider, (_, _) {});
    container.listen(blockedVendorsListProvider, (_, _) {});
    container.listen(discountedProductsProvider, (_, _) {});
    container.listen(
      recommendedStoresForIngredientProvider('Tomato'),
      (_, _) {},
    );
    container.listen(vendorOrdersProvider, (_, _) {});
    container.listen(vendorReviewsProvider, (_, _) {});
    container.listen(vendorProductsProvider('vendor'), (_, _) {});
    container.listen(appSearchProvider('mango'), (_, _) {});
    await container.read(allVendorsProvider.future);
    await container.read(allProductsProvider.future);
    await container.read(popularVendorsProvider.future);
    await container.read(vendorsByCategoryProvider('Vegetables').future);
    await container.read(vendorProfileProvider('vendor').future);

    await container
        .read(vendorStallProvider.notifier)
        .updateStall(category: 'Maritatas');

    expect(container.read(vendorStallProvider).category, 'Maritatas');
    await container.read(allVendorsProvider.future);
  });

  testWidgets(
    'changing the stall category saves without a circular dependency',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final prefs = await _prefs();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authProvider.overrideWith(_VendorUser.new),
          ],
          child: const MaterialApp(
            home: _CatalogHost(child: VendorStallSettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fruits').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Vegetables'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('CircularDependencyError'), findsNothing);
      expect(
        find.textContaining('Stall settings and operating hours saved!'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
