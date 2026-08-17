import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:palengkego/features/profile/application/blocked_vendors_provider.dart';
import 'package:palengkego/features/profile/application/favorites_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> buildContainer({
    List<String> favoriteIds = const [],
    List<String> blockedIds = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      'favorite_vendors': favoriteIds,
      'blocked_vendors': blockedIds,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('FavoritesNotifier', () {
    test('starts with an empty set of favorites', () async {
      final container = await buildContainer();

      expect(container.read(favoritesProvider), isEmpty);
    });

    test('starts with persisted favorite ids', () async {
      final container = await buildContainer(favoriteIds: ['v1', 'v2']);

      expect(container.read(favoritesProvider), containsAll(['v1', 'v2']));
    });

    test('toggle adds a vendor id when not yet favorited', () async {
      final container = await buildContainer();

      container.read(favoritesProvider.notifier).toggle('v1');
      expect(container.read(favoritesProvider), contains('v1'));
    });

    test('toggle persists favorite ids', () async {
      final container = await buildContainer();
      final prefs = container.read(sharedPreferencesProvider);

      container.read(favoritesProvider.notifier).toggle('v1');

      expect(prefs.getStringList('favorite_vendors'), ['v1']);
    });

    test('toggle removes a vendor id that is already favorited', () async {
      final container = await buildContainer();

      final notifier = container.read(favoritesProvider.notifier);
      notifier.toggle('v1');
      expect(container.read(favoritesProvider), contains('v1'));

      notifier.toggle('v1');
      expect(container.read(favoritesProvider), isNot(contains('v1')));
    });

    test('isFavorite returns correct boolean', () async {
      final container = await buildContainer();

      final notifier = container.read(favoritesProvider.notifier);
      expect(notifier.isFavorite('v2'), isFalse);

      notifier.toggle('v2');
      expect(notifier.isFavorite('v2'), isTrue);
    });

    test('multiple vendors can be favorited independently', () async {
      final container = await buildContainer();

      final notifier = container.read(favoritesProvider.notifier);
      notifier.toggle('v1');
      notifier.toggle('v3');
      notifier.toggle('v5');

      final state = container.read(favoritesProvider);
      expect(state, containsAll(['v1', 'v3', 'v5']));
      expect(state, hasLength(3));
    });

    test('toggling one vendor does not affect others', () async {
      final container = await buildContainer();

      final notifier = container.read(favoritesProvider.notifier);
      notifier.toggle('v1');
      notifier.toggle('v2');

      // Remove v1
      notifier.toggle('v1');

      final state = container.read(favoritesProvider);
      expect(state, isNot(contains('v1')));
      expect(state, contains('v2'));
    });
  });

  group('favoriteVendorsProvider', () {
    Future<List<MarketVendor>> readFavorites(
      ProviderContainer container,
    ) async {
      // Ensure the underlying async vendor data is resolved first.
      await container.read(allVendorsProvider.future);
      return container.read(favoriteVendorsProvider).value ?? [];
    }

    test('returns empty list when no favorites selected', () async {
      final container = await buildContainer();

      final vendors = await readFavorites(container);
      expect(vendors, isEmpty);
    });

    test('returns vendor objects for favorited ids', () async {
      final container = await buildContainer();

      // v1 and v2 are seeded in MockMarketRepository
      container.read(favoritesProvider.notifier).toggle('v1');
      container.read(favoritesProvider.notifier).toggle('v2');

      final vendors = await readFavorites(container);
      expect(vendors.length, 2);
      expect(vendors.map((v) => v.id), containsAll(['v1', 'v2']));
    });

    test('excludes blocked vendors from favorite list', () async {
      final container = await buildContainer(
        favoriteIds: ['v1'],
        blockedIds: ['v1'],
      );

      expect(container.read(favoritesProvider), contains('v1'));
      expect(container.read(blockedVendorsProvider), contains('v1'));
      expect(await readFavorites(container), isEmpty);
    });

    test('vendor list updates when a favorite is removed', () async {
      final container = await buildContainer();

      final notifier = container.read(favoritesProvider.notifier);
      notifier.toggle('v1');
      notifier.toggle('v2');

      expect((await readFavorites(container)).length, 2);

      notifier.toggle('v1'); // remove

      expect((await readFavorites(container)).length, 1);
      expect((await readFavorites(container)).first.id, 'v2');
    });
  });
}
