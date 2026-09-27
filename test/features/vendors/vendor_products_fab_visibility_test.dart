import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_products_screen.dart';

void main() {
  testWidgets(
    'VendorProductsScreen hides FAB and shows center button when 0 products exist',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentVendorIdProvider.overrideWithValue('test-vendor-empty'),
            vendorProductsProvider('test-vendor-empty').overrideWith(
              (ref) async => <VendorProduct>[],
            ),
          ],
          child: const MaterialApp(home: VendorProductsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Should show empty state message and centered button
      expect(find.text('No products yet.'), findsOneWidget);
      expect(find.text('Click below to add your first product.'), findsOneWidget);
      expect(find.text('Add Product'), findsOneWidget);

      // Verify that Scaffold.floatingActionButton is null
      final scaffoldState = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffoldState.floatingActionButton, isNull);
    },
  );

  testWidgets(
    'VendorProductsScreen shows FAB and hides center empty state when >= 1 product exists',
    (WidgetTester tester) async {
      final dummyProduct = VendorProduct(
        id: 'prod-1',
        vendorId: 'test-vendor-with-items',
        name: 'Fresh Tomatoes',
        category: 'Vegetables',
        price: 50.0,
        unit: 'kg',
        stockQuantity: 10,
        isActive: true,
        description: 'Fresh local tomatoes',
        imageUrl: '',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentVendorIdProvider.overrideWithValue('test-vendor-with-items'),
            vendorProductsProvider('test-vendor-with-items').overrideWith(
              (ref) async => [dummyProduct],
            ),
          ],
          child: const MaterialApp(home: VendorProductsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Empty state should NOT be present
      expect(find.text('No products yet.'), findsNothing);
      expect(find.text('Fresh Tomatoes'), findsOneWidget);

      // Verify that Scaffold.floatingActionButton IS present
      final scaffoldState = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffoldState.floatingActionButton, isNotNull);
    },
  );
}
