import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/data/mock_cart_repository.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/cart/domain/cart_repository.dart';

void main() {
  late MockCartRepository repository;

  setUp(() {
    MockCartRepository.clearTestState();
    repository = MockCartRepository();
  });

  ProviderContainer buildContainer(List<dynamic> extraOverrides) {
    final container = ProviderContainer(
      overrides: [
        cartRepositoryProvider.overrideWithValue(repository),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  CartItem item({
    required String vendorName,
    required String productName,
    required double price,
    String unit = 'kg',
    required String image,
    double quantity = 1.0,
  }) {
    return CartItem(
      productId: 'p-$vendorName-$productName',
      vendorName: vendorName,
      productName: productName,
      price: price,
      unit: unit,
      image: image,
      quantity: quantity,
    );
  }

  Future<void> add(ProviderContainer container, CartItem cartItem) async {
    await container.read(cartItemsProvider.notifier).addToCart(cartItem);
  }

  test('cartRepositoryProvider exposes a cart repository', () {
    final container = buildContainer([]);

    final cart = container.read(cartRepositoryProvider);

    expect(cart, isA<CartRepository>());
  });

  test(
    'cartItemsProvider reflects items added through the repository',
    () async {
      final container = buildContainer([]);

      await add(
        container,
        item(
          vendorName: 'Aling Nena',
          productName: 'Carrots',
          price: 120,
          image: 'carrots.png',
        ),
      );

      final items = await container.read(cartItemsProvider.future);
      expect(items, hasLength(1));
      expect(container.read(cartCountProvider).requireValue, 1);
    },
  );

  test(
    'cartItemsProvider keeps existing items after cart provider rebuilds',
    () async {
      final container = buildContainer([]);

      await add(
        container,
        item(
          vendorName: 'Aling Nena',
          productName: 'Carrots',
          price: 120,
          image: 'carrots.png',
        ),
      );

      expect(await container.read(cartItemsProvider.future), hasLength(1));

      container.invalidate(cartItemsProvider);

      final items = await container.read(cartItemsProvider.future);
      expect(items, hasLength(1));
      expect(items.single.productName, 'Carrots');
    },
  );

  test(
    'cartItemsProvider keeps existing items when a different item is added',
    () async {
      final container = buildContainer([]);

      await add(
        container,
        item(
          vendorName: 'Aling Nena',
          productName: 'Carrots',
          price: 120,
          image: 'carrots.png',
        ),
      );
      await add(
        container,
        item(
          vendorName: 'Mang Juan',
          productName: 'Bangus',
          price: 90,
          unit: 'pc',
          image: 'bangus.png',
        ),
      );

      final items = await container.read(cartItemsProvider.future);
      final itemNames = items.map((entry) => entry.productName).toList();

      expect(itemNames, ['Carrots', 'Bangus']);
      expect(container.read(cartCountProvider).requireValue, 2);
    },
  );

  test('cart state survives login and logout auth state changes', () async {
    final container = buildContainer([
      authProvider.overrideWith(_MutableAuthNotifier.new),
    ]);

    await add(
      container,
      item(
        vendorName: 'Diosa Fruit Stand',
        productName: 'Sweet Mangoes',
        price: 150,
        image: 'mango.png',
        quantity: 2,
      ),
    );
    await add(
      container,
      item(
        vendorName: 'Mang Juan',
        productName: 'Bangus',
        price: 90,
        unit: 'pc',
        image: 'bangus.png',
      ),
    );
    await container
        .read(cartItemsProvider.notifier)
        .toggleSelect('p-Mang Juan-Bangus', 'Mang Juan', 'Bangus', 'pc');

    expect(await container.read(cartItemsProvider.future), hasLength(2));
    expect(container.read(cartCountProvider).requireValue, 2);
    expect(container.read(cartSubtotalProvider).requireValue, 300);

    (container.read(authProvider.notifier) as _MutableAuthNotifier)
        .loginAsCustomer();

    expect(container.read(authProvider), MockUsers.customer);
    expect(await container.read(cartItemsProvider.future), hasLength(2));
    expect(container.read(cartCountProvider).requireValue, 2);
    expect(container.read(cartSubtotalProvider).requireValue, 300);

    (container.read(authProvider.notifier) as _MutableAuthNotifier)
        .logoutForTest();

    expect(container.read(authProvider), isNull);
    final items = await container.read(cartItemsProvider.future);
    expect(items, hasLength(2));
    expect(container.read(cartCountProvider).requireValue, 2);
    expect(items.map((entry) => entry.productName), [
      'Sweet Mangoes',
      'Bangus',
    ]);
  });
}

class _MutableAuthNotifier extends AuthNotifier {
  @override
  AppUser? build() => null;

  void loginAsCustomer() {
    state = MockUsers.customer;
  }

  void logoutForTest() {
    state = null;
  }
}
