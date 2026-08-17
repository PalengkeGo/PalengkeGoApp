import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/data/mock_cart_repository.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';
import 'package:palengkego/features/vendors/presentation/widgets/add_to_cart_bottom_sheet.dart';
import 'package:palengkego/features/vendors/presentation/widgets/vendor_profile_components.dart';

void main() {
  late MockCartRepository cartRepository;

  setUp(() {
    cartRepository = MockCartRepository();
    MockCartRepository.clearTestState();
  });

  Widget buildCard({required VendorProduct product}) {
    return ProviderScope(
      overrides: [cartRepositoryProvider.overrideWithValue(cartRepository)],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 260,
            child: VendorProfileProductCard(
              product: product,
              vendorName: 'Diosa Fruit Stand',
            ),
          ),
        ),
      ),
    );
  }

  VendorProduct product({required double stockQuantity}) {
    return VendorProduct(
      id: 'p1',
      vendorId: 'v1',
      name: 'Sweet Mangoes',
      description: 'Fresh mangoes',
      category: 'Fruits',
      price: 150,
      imageUrl: '',
      stockQuantity: stockQuantity,
    );
  }

  group('VendorProfileProductCard stock state', () {
    testWidgets(
      'out-of-stock product shows disabled state and does not open cart sheet',
      (tester) async {
        await tester.pumpWidget(buildCard(product: product(stockQuantity: 0)));

        expect(find.text('Out of stock'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();

        expect(find.byType(AddToCartBottomSheet), findsNothing);
        expect(cartRepository.items, isEmpty);
      },
    );

    testWidgets(
      'low-stock product shows remaining stock and opens add-to-cart sheet',
      (tester) async {
        await tester.pumpWidget(buildCard(product: product(stockQuantity: 3)));

        expect(find.text('Only 3 left'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(AddToCartBottomSheet), findsOneWidget);
      },
    );
  });
}
