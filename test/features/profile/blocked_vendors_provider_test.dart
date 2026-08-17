import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/profile/application/blocked_vendors_provider.dart';
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

  group('BlockedVendorsNotifier', () {
    test('starts with an empty blocked set', () async {
      final container = await buildContainer();

      expect(container.read(blockedVendorsProvider), isEmpty);
    });

    test('starts with persisted blocked ids', () async {
      final container = await buildContainer(blockedIds: ['v1']);

      expect(container.read(blockedVendorsProvider), contains('v1'));
    });

    test('block adds a vendor id', () async {
      final container = await buildContainer();

      container.read(blockedVendorsProvider.notifier).block('v1');

      expect(container.read(blockedVendorsProvider), contains('v1'));
      expect(
        container.read(blockedVendorsProvider.notifier).isBlocked('v1'),
        isTrue,
      );
    });

    test('block persists blocked ids', () async {
      final container = await buildContainer();
      final prefs = container.read(sharedPreferencesProvider);

      container.read(blockedVendorsProvider.notifier).block('v1');

      expect(prefs.getStringList('blocked_vendors'), ['v1']);
    });

    test('unblock removes a vendor id without affecting others', () async {
      final container = await buildContainer();
      final notifier = container.read(blockedVendorsProvider.notifier);

      notifier.block('v1');
      notifier.block('v2');
      notifier.unblock('v1');

      expect(container.read(blockedVendorsProvider), isNot(contains('v1')));
      expect(container.read(blockedVendorsProvider), contains('v2'));
    });
  });

  group('blockedVendorsListProvider', () {
    test('returns vendor objects for blocked vendor ids', () async {
      final container = await buildContainer();

      container.read(blockedVendorsProvider.notifier).block('v1');
      container.read(blockedVendorsProvider.notifier).block('v2');

      // Ensure the underlying async vendor data is resolved first.
      await container.read(allVendorsProvider.future);

      final vendors = container.read(blockedVendorsListProvider).value ?? [];

      expect(vendors.map((vendor) => vendor.id), containsAll(['v1', 'v2']));
    });
  });
}
