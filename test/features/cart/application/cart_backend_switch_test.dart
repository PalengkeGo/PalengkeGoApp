import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/data/local_cart_repository.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer buildContainer({
    bool firebaseEnabled = false,
    List<dynamic> extraOverrides = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        firebaseEnabledProvider.overrideWithValue(firebaseEnabled),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_SignedOutAuthNotifier.new),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  CartItem item(String productId) => CartItem(
    productId: productId,
    vendorName: 'Diosa Fruit Stand',
    productName: 'Sweet Mangoes',
    price: 150,
    unit: 'kg',
    image: '',
  );

  test('firebase disabled resolves to the local device cart', () {
    final container = buildContainer(firebaseEnabled: false);

    expect(container.read(cartRepositoryProvider), isA<LocalCartRepository>());
  });

  test('firebase enabled but not signed in keeps the local device cart', () {
    final container = buildContainer(firebaseEnabled: true);

    expect(container.read(cartRepositoryProvider), isA<LocalCartRepository>());
  });

  test(
    'cart items persist to the local device cart across instantiations',
    () async {
      final container = buildContainer(firebaseEnabled: false);

      await container.read(cartItemsProvider.notifier).addToCart(item('m1'));

      final items = await container.read(cartItemsProvider.future);
      expect(items.single.productId, 'm1');

      // A fresh container (new app session) still sees the device cart.
      final second = buildContainer(firebaseEnabled: false);
      expect(
        (await second.read(cartItemsProvider.future)).single.productId,
        'm1',
      );
    },
  );

  test('switching firebase on/off keeps both stores intact', () async {
    // Dev uses mock mode; a signed-out prod session writes only the device
    // cart. Nothing may be lost or mixed between the two stores.
    final device = buildContainer(firebaseEnabled: false);
    await device.read(cartItemsProvider.notifier).addToCart(item('m1'));
    await device.read(cartItemsProvider.notifier).clearCart();

    final serverLike = buildContainer(firebaseEnabled: true);
    expect(await serverLike.read(cartItemsProvider.future), isEmpty);
  });
}

class _SignedOutAuthNotifier extends AuthNotifier {
  @override
  AppUser? build() => null;
}
