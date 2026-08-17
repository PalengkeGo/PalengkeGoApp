import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/data/mock_order_repository.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  late MockOrderRepository repository;

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() {
    repository = MockOrderRepository();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        orderRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith(_TestAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  OrderLineItem lineItem({
    required String productName,
    required double price,
    String unit = 'kg',
    String image = 'item.png',
    double quantity = 1,
  }) {
    return OrderLineItem(
      productId: 'p_$productName',
      productName: productName,
      quantity: quantity,
      unitPrice: price,
      unit: unit,
      image: image,
    );
  }

  Map<String, (String, List<OrderLineItem>)> grouped(
    List<(String vendor, List<OrderLineItem> items)> entries,
  ) {
    return {for (final entry in entries) entry.$1: ('', entry.$2)};
  }

  group('OrderRepository', () {
    test('returns no orders for an empty grouped item list', () async {
      final orders = await repository.placeOrders(
        groupedItems: {},
        isPickup: false,
      );

      expect(orders, isEmpty);
    });

    test('groups created orders by vendor', () async {
      final orders = await repository.placeOrders(
        groupedItems: grouped([
          (
            'Aling Nena Vegetables',
            [
              lineItem(productName: 'Carrots', price: 120),
              lineItem(productName: 'Baguio Beans', price: 140),
            ],
          ),
          (
            'Mang Pedro Seafood',
            [lineItem(productName: 'Bangus', price: 90, unit: 'pc')],
          ),
        ]),
        isPickup: false,
      );

      expect(orders, hasLength(2));
      expect(orders.map((order) => order.vendorName), [
        'Aling Nena Vegetables',
        'Mang Pedro Seafood',
      ]);
      expect(orders.first.items.map((item) => item.productName), [
        'Carrots',
        'Baguio Beans',
      ]);
      expect(orders.last.items.single.productName, 'Bangus');
    });

    test('copies cart item details into order line items', () async {
      final orders = await repository.placeOrders(
        groupedItems: grouped([
          (
            'Aling Nena Vegetables',
            [
              lineItem(
                productName: 'Carrots',
                price: 120,
                image: 'carrots.png',
                quantity: 3,
              ),
            ],
          ),
        ]),
        isPickup: false,
      );

      final lineItem2 = orders.single.items.single;
      expect(lineItem2.productName, 'Carrots');
      expect(lineItem2.quantity, 3);
      expect(lineItem2.unitPrice, 120);
      expect(lineItem2.image, 'carrots.png');
      expect(lineItem2.total, 360);
    });

    test('pickup orders start as pending', () async {
      final orders = await repository.placeOrders(
        groupedItems: grouped([
          (
            'Aling Nena Vegetables',
            [lineItem(productName: 'Carrots', price: 120)],
          ),
        ]),
        isPickup: true,
      );

      expect(orders.single.status, OrderStatus.pending);
      expect(orders.single.statusLabel, 'Pending');
      expect(orders.single.isPickup, isTrue);
    });

    test(
      'delivery orders start as pending until a vendor accepts them',
      () async {
        final orders = await repository.placeOrders(
          groupedItems: grouped([
            (
              'Aling Nena Vegetables',
              [lineItem(productName: 'Carrots', price: 120)],
            ),
          ]),
          isPickup: false,
        );

        expect(orders.single.status, OrderStatus.pending);
        expect(orders.single.statusLabel, 'Pending');
        expect(orders.single.isPickup, isFalse);
      },
    );

    test(
      'cancelOrder moves a pending order to cancelled within the cancel window',
      () async {
        await repository.placeOrders(
          groupedItems: grouped([
            (
              'Aling Nena Vegetables',
              [lineItem(productName: 'Carrots', price: 120)],
            ),
          ]),
          isPickup: false,
        );
        final container = buildContainer();
        final orders = await container.read(orderServiceProvider.future);
        final order = orders.first;

        await container
            .read(orderServiceProvider.notifier)
            .cancelOrder(
              order.id,
              now: order.placedAt.add(const Duration(minutes: 4)),
            );

        final updated = (await container.read(
          orderServiceProvider.future,
        )).firstWhere((entry) => entry.id == order.id);
        expect(updated.status, OrderStatus.cancelled);
      },
    );

    test('cancelOrder rejects cancellation after the cancel window', () async {
      await repository.placeOrders(
        groupedItems: grouped([
          (
            'Aling Nena Vegetables',
            [lineItem(productName: 'Carrots', price: 120)],
          ),
        ]),
        isPickup: false,
      );
      final container = buildContainer();
      final orders = await container.read(orderServiceProvider.future);
      final order = orders.first;

      await expectLater(
        container
            .read(orderServiceProvider.notifier)
            .cancelOrder(
              order.id,
              now: order.placedAt.add(const Duration(minutes: 6)),
            ),
        throwsA(
          isA<OrderFailure>().having(
            (e) => e.type,
            'type',
            OrderFailureType.cancelWindowExpired,
          ),
        ),
      );
      final updated = (await container.read(
        orderServiceProvider.future,
      )).firstWhere((entry) => entry.id == order.id);
      expect(updated.status, OrderStatus.pending);
    });

    test(
      'cancelOrder rejects terminal orders even within the cancel window',
      () async {
        await repository.placeOrders(
          groupedItems: grouped([
            (
              'Aling Nena Vegetables',
              [lineItem(productName: 'Carrots', price: 120)],
            ),
          ]),
          isPickup: false,
        );
        final container = buildContainer();
        final orders = await container.read(orderServiceProvider.future);
        final order = orders.first;

        // Walk the order through the state machine to a terminal state.
        await container
            .read(orderServiceProvider.notifier)
            .updateOrderStatus(order.id, OrderStatus.preparing);
        await container
            .read(orderServiceProvider.notifier)
            .updateOrderStatus(order.id, OrderStatus.ready);
        await container
            .read(orderServiceProvider.notifier)
            .updateOrderStatus(order.id, OrderStatus.completed);
        // Let the invalidated provider rebuild before cancelOrder reads it.
        await container.read(orderServiceProvider.future);

        await expectLater(
          container
              .read(orderServiceProvider.notifier)
              .cancelOrder(
                order.id,
                now: order.placedAt.add(const Duration(minutes: 1)),
              ),
          throwsA(
            isA<OrderFailure>().having(
              (e) => e.type,
              'type',
              OrderFailureType.alreadyTerminal,
            ),
          ),
        );
        final updated = (await container.read(
          orderServiceProvider.future,
        )).firstWhere((entry) => entry.id == order.id);
        expect(updated.status, OrderStatus.completed);
      },
    );
  });
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AppUser? build() => MockUsers.customer;
}
