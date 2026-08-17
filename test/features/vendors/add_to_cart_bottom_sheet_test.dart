import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/data/mock_cart_repository.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';
import 'package:palengkego/features/vendors/presentation/widgets/add_to_cart_bottom_sheet.dart';

void main() {
  late MockCartRepository repository;

  setUp(() {
    MockCartRepository.clearTestState();
    repository = MockCartRepository();
  });

  group('AddToCartBottomSheet', () {
    testWidgets('adds a typed vendor product to the shared cart', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const product = VendorProduct(
        id: 'p1',
        vendorId: 'v1',
        name: 'Bangus',
        description: 'Fresh milkfish',
        category: 'Seafood',
        price: 80,
        unit: 'kg',
        imageUrl: '',
        stockQuantity: 10,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [cartRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            home: Scaffold(
              body: AddToCartBottomSheet(
                vendorName: 'Aling Nena',
                product: product,
              ),
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('Add to cart'));
      await tester.tap(find.text('Add to cart'));
      await tester.pump();

      expect(repository.items, hasLength(1));
      expect(repository.items.single.vendorName, 'Aling Nena');
      expect(repository.items.single.productName, 'Bangus');
      expect(repository.items.single.productId, 'p1');
      expect(repository.items.single.unit, 'kg');
    });

    testWidgets('uses piece pricing when product is sold per piece', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const product = VendorProduct(
        id: 'p2',
        vendorId: 'v1',
        name: 'Egg',
        description: 'Fresh eggs',
        category: 'Eggs',
        price: 10,
        unit: 'pc',
        imageUrl: '',
        stockQuantity: 12,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [cartRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            home: Scaffold(
              body: AddToCartBottomSheet(
                vendorName: 'Aling Nena',
                product: product,
              ),
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('3 pc'));
      await tester.tap(find.text('3 pc'));
      await tester.pump();
      await tester.ensureVisible(find.text('Add to cart'));
      await tester.tap(find.text('Add to cart'));
      await tester.pump();

      expect(repository.items, hasLength(1));
      expect(repository.items.single.productName, 'Egg');
      expect(repository.items.single.quantity, 3.0);
      expect(repository.items.single.unit, 'pc');
      expect(repository.items.single.total, 30);
    });

    testWidgets('uses kg divisions when a product is priced per kg', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const product = VendorProduct(
        id: 'p2',
        vendorId: 'v1',
        name: 'Sweet Mangoes',
        description: 'Sweet and ripe fruit',
        category: 'Fruits',
        price: 150,
        unit: 'kg',
        imageUrl: '',
        stockQuantity: 12,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [cartRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            home: Scaffold(
              body: AddToCartBottomSheet(
                vendorName: 'Diosa Fruit Stand',
                product: product,
              ),
            ),
          ),
        ),
      );

      expect(find.text('1/4 kg'), findsOneWidget);
      expect(find.text('1/2 kg'), findsOneWidget);
      expect(find.text('3/4 kg'), findsOneWidget);
      expect(find.text('1 kg'), findsOneWidget);
      expect(find.text('1 pc'), findsNothing);
    });

    testWidgets('preserves image, stock, and discounted price in cart item', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const product = VendorProduct(
        id: 'p3',
        vendorId: 'v1',
        name: 'Pork Belly',
        description: 'Fresh pork belly',
        category: 'Meat',
        price: 200,
        unit: 'kg',
        imageUrl: 'https://example.com/pork.png',
        stockQuantity: 4,
        discountPercentage: 25,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [cartRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            home: Scaffold(
              body: AddToCartBottomSheet(
                vendorName: 'Daily Meat Shop',
                product: product,
              ),
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('Add to cart'));
      await tester.tap(find.text('Add to cart'));
      await tester.pump();

      expect(repository.items, hasLength(1));
      expect(repository.items.single.price, 150);
      expect(repository.items.single.image, 'https://example.com/pork.png');
      expect(repository.items.single.stockQuantity, 4);
    });

    testWidgets('does not allow quantity above stock quantity', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const product = VendorProduct(
        id: 'p4',
        vendorId: 'v1',
        name: 'Bangus',
        description: 'Fresh milkfish',
        category: 'Seafood',
        price: 80,
        unit: 'kg',
        imageUrl: '',
        stockQuantity: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [cartRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            home: Scaffold(
              body: AddToCartBottomSheet(
                vendorName: 'Mang Juan',
                product: product,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Maximum stock reached'), findsOneWidget);
      expect(repository.items, isEmpty);
    });

    testWidgets('does not add an out-of-stock product to the cart', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const product = VendorProduct(
        id: 'p5',
        vendorId: 'v1',
        name: 'Mango',
        description: 'Fresh mango',
        category: 'Fruits',
        price: 150,
        unit: 'kg',
        imageUrl: '',
        stockQuantity: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [cartRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            home: Scaffold(
              body: AddToCartBottomSheet(
                vendorName: 'Diosa Fruit Stand',
                product: product,
              ),
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('Add to cart'));
      await tester.tap(find.text('Add to cart'));
      await tester.pump();

      expect(repository.items, isEmpty);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add to cart'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('shown bottom sheet does not throw on presentation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const product = VendorProduct(
        id: 'p1',
        vendorId: 'v1',
        name: 'Bangus',
        description: 'Fresh milkfish',
        category: 'Seafood',
        price: 80,
        unit: 'kg',
        imageUrl: '',
        stockQuantity: 10,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [cartRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      AddToCartBottomSheet.show(
                        context,
                        vendorName: 'Aling Nena',
                        product: product,
                      );
                    },
                    child: const Text('Show'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AddToCartBottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
