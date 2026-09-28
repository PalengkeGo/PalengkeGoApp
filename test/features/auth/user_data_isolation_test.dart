import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/profile/application/favorites_provider.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('User data (addresses & favorites) is scoped to the user account and isolated on logout', () async {
    // 1. Initial guest state: no favorites, no saved addresses, no orders
    expect(container.read(favoritesProvider), isEmpty);
    expect(container.read(preferencesProvider).savedAddresses, isEmpty);
    expect(container.read(orderServiceProvider).value ?? [], isEmpty);

    // 2. User A logs in
    const userA = AppUser(
      uid: 'user-aaa',
      email: 'usera@example.com',
      role: UserRole.customer,
    );
    container.read(authProvider.notifier).updateUser(userA);

    // User A adds a favorite and an address
    container.read(favoritesProvider.notifier).toggle('vendor-stall-1');
    expect(container.read(favoritesProvider), contains('vendor-stall-1'));

    const addrA = DeliveryAddress(
      label: 'Home',
      primaryAddress: 'Naga City',
      streetAddress: '123 Main St',
    );
    container.read(preferencesProvider.notifier).saveDeliveryAddress(addrA);
    expect(container.read(preferencesProvider).savedAddresses.length, 1);
    expect(container.read(preferencesProvider).savedAddresses.first.streetAddress, '123 Main St');

    // 3. User A logs out
    await container.read(authProvider.notifier).logout();

    // Guest state after logout should be clean
    expect(container.read(authProvider), isNull);
    expect(container.read(favoritesProvider), isEmpty);
    expect(container.read(preferencesProvider).savedAddresses, isEmpty);
    expect(container.read(orderServiceProvider).value ?? [], isEmpty);

    // 4. User B logs in
    const userB = AppUser(
      uid: 'user-bbb',
      email: 'userb@example.com',
      role: UserRole.customer,
    );
    container.read(authProvider.notifier).updateUser(userB);

    // User B has their own separate data (not user A's)
    expect(container.read(favoritesProvider), isEmpty);
    expect(container.read(preferencesProvider).savedAddresses, isEmpty);

    // User B adds their own favorite
    container.read(favoritesProvider.notifier).toggle('vendor-stall-2');
    expect(container.read(favoritesProvider), contains('vendor-stall-2'));
    expect(container.read(favoritesProvider), isNot(contains('vendor-stall-1')));

    // 5. User A logs back in
    container.read(authProvider.notifier).updateUser(userA);

    // User A's favorites are restored
    expect(container.read(favoritesProvider), contains('vendor-stall-1'));
    expect(container.read(favoritesProvider), isNot(contains('vendor-stall-2')));
  });
}
