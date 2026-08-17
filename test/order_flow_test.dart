import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/orders/data/mock_order_repository.dart';
import 'package:palengkego/features/orders/data/shared_order_store.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedOrderStore store;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    store = SharedOrderStore();
    await store.load();
  });

  test('place order and get orders for vendor', () async {
    final repo = MockOrderRepository(store: store);

    // Check initial orders count
    final initialOrders = await repo.getOrdersForVendor('v1');

    final groupedItems = {
      'Diosa Fruit Stand': (
        '',
        [
          const OrderLineItem(
            productId: 'p1',
            productName: 'Sweet Mangoes',
            unitPrice: 150.0,
            unit: 'kg',
            image: '',
            quantity: 1.5,
          ),
        ],
      ),
    };

    final created = await repo.placeOrders(
      groupedItems: groupedItems,
      isPickup: false,
      customerUid: 'customer-001',
      customerName: 'Maria Santos',
    );
    expect(created, isNotEmpty);

    // Get orders for vendor Diosa Fruit Stand
    final vendorOrders = await repo.getOrdersForVendor('v1');

    expect(vendorOrders.length, greaterThan(initialOrders.length));
  });
}
