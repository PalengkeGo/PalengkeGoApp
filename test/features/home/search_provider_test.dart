import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/home/application/search_provider.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> buildContainer({
    List<String> blockedIds = const [],
  }) async {
    SharedPreferences.setMockInitialValues({'blocked_vendors': blockedIds});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<List<MarketVendor>> readVendors(
    ProviderContainer container,
    String category,
  ) async {
    // Ensure the underlying async vendor data is resolved first.
    await container.read(vendorsByCategoryProvider(category).future);
    return container.read(filteredVendorsProvider(category)).value ?? [];
  }

  group('SearchQueryNotifier', () {
    test('starts with an empty query', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(searchQueryProvider), isEmpty);
    });

    test('update() sets the query string', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(searchQueryProvider.notifier).update('bangus');
      expect(container.read(searchQueryProvider), 'bangus');
    });

    test('clear() resets the query to empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(searchQueryProvider.notifier);
      notifier.update('tilapia');
      expect(container.read(searchQueryProvider), isNotEmpty);

      notifier.clear();
      expect(container.read(searchQueryProvider), isEmpty);
    });
  });

  group('filteredVendorsProvider', () {
    test('returns all vendors in category when query is empty', () async {
      final container = await buildContainer();

      final all = await readVendors(container, 'All');
      expect(all, isNotEmpty);
    });

    test('filters vendors by name (case-insensitive)', () async {
      final container = await buildContainer();

      // Seed a query that matches a known vendor name fragment in mock data
      container.read(searchQueryProvider.notifier).update('diosa');

      final results = await readVendors(container, 'All');
      // All results should contain 'diosa' in name or category
      for (final v in results) {
        expect(
          v.name.toLowerCase().contains('diosa') ||
              v.category.toLowerCase().contains('diosa'),
          isTrue,
        );
      }
    });

    test('filters vendors by category chip + query simultaneously', () async {
      final container = await buildContainer();

      // Query that should match nothing in the Fish category
      container.read(searchQueryProvider.notifier).update('zzznomatch_xyz');

      final results = await readVendors(container, 'Fish');
      expect(results, isEmpty);
    });

    test('returns empty list when no vendors match query', () async {
      final container = await buildContainer();

      container
          .read(searchQueryProvider.notifier)
          .update('qqqqq_no_vendor_ever');

      final results = await readVendors(container, 'All');
      expect(results, isEmpty);
    });

    test('excludes blocked vendors from filtered results', () async {
      final container = await buildContainer(blockedIds: ['v1']);

      final results = await readVendors(container, 'All');

      expect(results.map((vendor) => vendor.id), isNot(contains('v1')));
    });

    test('results update when query changes', () async {
      final container = await buildContainer();

      final notifier = container.read(searchQueryProvider.notifier);

      // Initially all vendors
      final allCount = (await readVendors(container, 'All')).length;

      // Apply a non-matching query
      notifier.update('zzznomatch');
      expect(await readVendors(container, 'All'), isEmpty);

      // Clear query — should restore all
      notifier.clear();
      expect((await readVendors(container, 'All')).length, allCount);
    });
  });
}
