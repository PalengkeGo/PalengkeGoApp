import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/mock/mock_data.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'app catalog starts without bundled stalls, products or reviews',
    () async {
      // A fresh isolate does not inherit the test-only catalog loader.
      final sizes = await Isolate.run(
        () => [
          MockDataService.featuredVendors.length,
          MockDataService.products.length,
          MockDataService.reviews.length,
        ],
      );
      expect(sizes, [0, 0, 0]);
    },
  );
  test('empty catalog does not resurrect persisted demo products', () async {
    MockDataService.featuredVendors = [];
    MockDataService.products = [];
    MockDataService.reviews = [];
    SharedPreferences.setMockInitialValues({
      'vendor_custom_products_v1':
          '[{"id":"p1","vendorId":"v1","name":"Demo Mango","price":100}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(await container.read(allVendorsProvider.future), isEmpty);
    expect(await container.read(allProductsProvider.future), isEmpty);
  });
}
