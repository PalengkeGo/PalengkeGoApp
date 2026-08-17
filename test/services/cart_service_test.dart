import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/data/mock_cart_repository.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';

void main() {
  late MockCartRepository repository;
  late ProviderContainer container;

  setUp(() {
    MockCartRepository.clearTestState();
    repository = MockCartRepository();
    container = ProviderContainer(
      overrides: [cartRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  CartItem item({
    String vendorName = 'Aling Nena',
    String productName = 'Carrots',
    double price = 120,
    String unit = 'kg',
    String image = 'carrots.png',
    double quantity = 1.0,
    bool selected = true,
    double stockQuantity = 10.0,
  }) {
    return CartItem(
      productId: 'p-$vendorName-$productName',
      vendorName: vendorName,
      productName: productName,
      price: price,
      unit: unit,
      image: image,
      quantity: quantity,
      selected: selected,
      stockQuantity: stockQuantity,
    );
  }

  Future<List<CartItem>> readCart() {
    return container.read(cartItemsProvider.future);
  }

  group('CartRepository', () {
    test('adds a new item and updates selected totals', () async {
      await container.read(cartItemsProvider.notifier).addToCart(item());

      final items = await readCart();
      expect(items, hasLength(1));
      expect(container.read(cartCountProvider).requireValue, 1);
      expect(container.read(cartSubtotalProvider).requireValue, 120);
      expect(items.single.vendorName, 'Aling Nena');
      expect(items.single.productName, 'Carrots');
    });

    test(
      'adding the same vendor product and unit increments quantity',
      () async {
        final notifier = container.read(cartItemsProvider.notifier);
        await notifier.addToCart(item());
        await notifier.addToCart(item());

        final items = await readCart();
        expect(items, hasLength(1));
        expect(items.single.quantity, 2);
        expect(container.read(cartCountProvider).requireValue, 1);
        expect(container.read(cartSubtotalProvider).requireValue, 240);
      },
    );

    test('adding a different product keeps existing cart items', () async {
      final notifier = container.read(cartItemsProvider.notifier);
      await notifier.addToCart(item());
      await notifier.addToCart(
        item(
          vendorName: 'Mang Juan',
          productName: 'Bangus',
          price: 90,
          unit: 'pc',
          image: 'bangus.png',
        ),
      );

      final items = await readCart();
      expect(items, hasLength(2));
      expect(items.map((entry) => entry.productName), ['Carrots', 'Bangus']);
      expect(container.read(cartSubtotalProvider).requireValue, 210);
    });

    test('preserves stock quantity when adding an item', () async {
      await container
          .read(cartItemsProvider.notifier)
          .addToCart(item(stockQuantity: 7));

      final items = await readCart();
      expect(items.single.stockQuantity, 7);
    });

    test('updateQuantity removes an item when quantity is zero', () async {
      final notifier = container.read(cartItemsProvider.notifier);
      await notifier.addToCart(item());
      await notifier.updateQuantity(
        'p-Aling Nena-Carrots',
        'Aling Nena',
        'Carrots',
        'kg',
        0,
      );

      final items = await readCart();
      expect(items, isEmpty);
      expect(container.read(cartCountProvider).requireValue, 0);
      expect(container.read(cartSubtotalProvider).requireValue, 0);
    });

    test(
      'selectAll false excludes items from selected count and subtotal',
      () async {
        final notifier = container.read(cartItemsProvider.notifier);
        await notifier.addToCart(item());
        await notifier.addToCart(
          item(
            vendorName: 'Mang Juan',
            productName: 'Bangus',
            price: 90,
            unit: 'pc',
            image: 'bangus.png',
          ),
        );
        await notifier.selectAll(false);

        final items = await readCart();
        expect(items, hasLength(2));
        expect(container.read(cartCountProvider).requireValue, 2);
        expect(container.read(cartSubtotalProvider).requireValue, 0);
        expect(items.every((entry) => !entry.selected), isTrue);
      },
    );

    test('clearCart removes every item', () async {
      final notifier = container.read(cartItemsProvider.notifier);
      await notifier.addToCart(item());
      await notifier.addToCart(
        item(
          vendorName: 'Mang Juan',
          productName: 'Bangus',
          price: 90,
          unit: 'pc',
          image: 'bangus.png',
        ),
      );
      await notifier.clearCart();

      final items = await readCart();
      expect(items, isEmpty);
      expect(container.read(cartCountProvider).requireValue, 0);
      expect(container.read(cartSubtotalProvider).requireValue, 0);
    });
  });
}
