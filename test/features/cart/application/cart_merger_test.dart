import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/cart/application/cart_merger.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';

CartItem item({
  required String productId,
  String vendorName = 'Diosa Fruit Stand',
  String productName = 'Mango',
  double price = 100.0,
  String unit = 'kg',
  double quantity = 1.0,
  bool selected = true,
  double stockQuantity = 10.0,
}) => CartItem(
  productId: productId,
  vendorName: vendorName,
  productName: productName,
  price: price,
  unit: unit,
  image: '',
  quantity: quantity,
  selected: selected,
  stockQuantity: stockQuantity,
);

void main() {
  group('mergeCarts (docs/cart_merge_rule.md — Option A)', () {
    test(
      'sums quantity when the same (productId, unit) exists on both sides',
      () {
        final result = mergeCarts(
          deviceCart: [
            item(productId: 'm1', quantity: 0.5, price: 90.0, selected: false),
          ],
          serverCart: [item(productId: 'm1', quantity: 1.0)],
        );

        expect(result.addedFromDevice, 0);
        expect(result.items, hasLength(1));
        expect(result.items.single.quantity, 1.5);
      },
    );

    test('server wins for price, stock, image and selection on a match', () {
      final result = mergeCarts(
        deviceCart: [
          item(
            productId: 'm1',
            price: 90.0,
            stockQuantity: 5.0,
            selected: false,
          ),
        ],
        serverCart: [item(productId: 'm1', price: 110.0, stockQuantity: 12.0)],
      );

      final merged = result.items.single;
      expect(merged.price, 110.0);
      expect(merged.stockQuantity, 12.0);
      expect(merged.selected, true);
      expect(merged.quantity, 2.0);
    });

    test('keeps server-only rows untouched', () {
      final result = mergeCarts(
        deviceCart: [item(productId: 'm1')],
        serverCart: [
          item(productId: 's1', productName: 'Banana'),
          item(productId: 's2', productName: 'Apple', selected: false),
        ],
      );

      expect(result.items.map((i) => i.productId), ['s1', 's2', 'm1']);
      expect(result.items[1].selected, false);
      expect(result.items[1].quantity, 1.0);
      expect(result.addedFromDevice, 1);
    });

    test('appends device-only rows with their own state', () {
      final result = mergeCarts(
        deviceCart: [
          item(productId: 'd1', price: 50.0, stockQuantity: 3.0),
          item(productId: 'd2', selected: false, quantity: 2.0),
        ],
        serverCart: [],
      );

      expect(result.addedFromDevice, 2);
      expect(result.items, hasLength(2));
      expect(result.items[0].price, 50.0);
      expect(result.items[1].selected, false);
    });

    test('never merges same product across different units (kg vs pc)', () {
      final result = mergeCarts(
        deviceCart: [item(productId: 'e1', unit: 'kg')],
        serverCart: [item(productId: 'e1', unit: 'pc')],
      );

      expect(result.items, hasLength(2));
      expect(result.addedFromDevice, 1);
    });

    test('is idempotent: re-merging an empty device cart changes nothing', () {
      final deviceCart = [item(productId: 'd1')];
      final serverCart = [item(productId: 's1', quantity: 2.0)];

      final first = mergeCarts(deviceCart: deviceCart, serverCart: serverCart);
      final second = mergeCarts(
        // the device cart was cleared after the first merge
        deviceCart: <CartItem>[],
        serverCart: first.items,
      );

      expect(second.items, hasLength(2));
      expect(second.items[0].quantity, 2.0);
      expect(second.addedFromDevice, 0);
    });

    test(
      'server rows are never dropped even when quantity would go to zero',
      () {
        final result = mergeCarts(
          deviceCart: [item(productId: 'x', quantity: 0, selected: false)],
          serverCart: [item(productId: 'x', quantity: 1.0)],
        );

        expect(result.items, hasLength(1));
        expect(result.items.single.quantity, 1.0);
      },
    );
  });
}
