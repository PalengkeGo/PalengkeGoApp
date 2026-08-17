import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/cart/data/local_cart_repository.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

CartItem item({
  required String productId,
  String vendorName = 'Diosa Fruit Stand',
  String productName = 'Mango',
  double price = 100.0,
  String unit = 'kg',
  String image = '',
  double quantity = 1.0,
  bool selected = true,
  double stockQuantity = 10.0,
}) => CartItem(
  productId: productId,
  vendorName: vendorName,
  productName: productName,
  price: price,
  unit: unit,
  image: image,
  quantity: quantity,
  selected: selected,
  stockQuantity: stockQuantity,
);

void main() {
  late LocalCartRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<LocalCartRepository> freshRepository() async =>
      LocalCartRepository(await SharedPreferences.getInstance());

  setUp(() async {
    repository = await freshRepository();
  });

  group('LocalCartRepository (SharedPreferences device cart)', () {
    test('starts empty and persists across repository instances', () async {
      expect(await repository.getCartItems(), isEmpty);

      await repository.addToCart(item(productId: 'm1'));
      repository = await freshRepository();
      final items = await repository.getCartItems();
      expect(items, hasLength(1));
      expect(items.single.productId, 'm1');
    });

    test('sums quantity on add for the same (productId, unit)', () async {
      await repository.addToCart(item(productId: 'm1', quantity: 0.5));
      await repository.addToCart(item(productId: 'm1', quantity: 1.0));

      final items = await repository.getCartItems();
      expect(items, hasLength(1));
      expect(items.single.quantity, 1.5);
    });

    test(
      'holds kg and pc rows of the same product as separate items',
      () async {
        await repository.addToCart(item(productId: 'm1', unit: 'kg'));
        await repository.addToCart(item(productId: 'm1', unit: 'pc'));

        expect(await repository.getCartItems(), hasLength(2));
      },
    );

    test(
      'updateCartItemQuantity replaces quantity and removes at zero',
      () async {
        await repository.addToCart(item(productId: 'm1', quantity: 2.0));
        await repository.updateCartItemQuantity(
          productId: 'm1',
          vendorName: 'A',
          productName: 'Mango',
          unit: 'kg',
          quantity: 0.25,
        );
        expect((await repository.getCartItems()).single.quantity, 0.25);

        await repository.updateCartItemQuantity(
          productId: 'm1',
          vendorName: 'A',
          productName: 'Mango',
          unit: 'kg',
          quantity: 0,
        );
        expect(await repository.getCartItems(), isEmpty);
      },
    );

    test('toggleItemSelection flips only the matching row', () async {
      await repository.addToCart(item(productId: 'm1'));
      await repository.addToCart(item(productId: 'm2'));

      await repository.toggleItemSelection(
        productId: 'm1',
        vendorName: 'A',
        productName: 'Mango',
        unit: 'kg',
      );

      final items = await repository.getCartItems();
      expect(items.firstWhere((i) => i.productId == 'm1').selected, false);
      expect(items.firstWhere((i) => i.productId == 'm2').selected, true);
    });

    test('selectAll, removeCartItem, removeSelectedItems, clearCart', () async {
      await repository.addToCart(item(productId: 'm1'));
      await repository.addToCart(item(productId: 'm2', selected: false));
      await repository.addToCart(item(productId: 'm3'));

      await repository.selectAll(false);
      var items = await repository.getCartItems();
      expect(items.every((i) => !i.selected), true);

      await repository.selectAll(true);
      await repository.removeSelectedItems();
      expect(await repository.getCartItems(), isEmpty);

      await repository.addToCart(item(productId: 'm1'));
      await repository.addToCart(item(productId: 'm2'));
      await repository.removeCartItem(
        productId: 'm1',
        vendorName: 'A',
        productName: 'Mango',
        unit: 'kg',
      );
      expect((await repository.getCartItems()).single.productId, 'm2');

      await repository.clearCart();
      expect(await repository.getCartItems(), isEmpty);
    });

    test('replaceAll overwrites the persisted cart', () async {
      await repository.addToCart(item(productId: 'm1'));
      await repository.replaceAll([item(productId: 'n1')]);

      final items = await repository.getCartItems();
      expect(items, hasLength(1));
      expect(items.single.productId, 'n1');
    });
  });
}
