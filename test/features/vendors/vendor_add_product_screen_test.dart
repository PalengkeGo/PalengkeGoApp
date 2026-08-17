import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_add_product_screen.dart';

void main() {
  testWidgets(
    'VendorAddProductScreen updates price label when selling unit is toggled',
    (WidgetTester tester) async {
      // Provide a mocked router or just a basic app wrapper since it doesn't navigate on init
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: VendorAddProductScreen())),
      );

      // Initial state: unit is unselected, label should be just 'Price'
      expect(find.text('Price'), findsOneWidget);

      // Tap 'Per Piece (pc)'
      await tester.tap(find.text('Per Piece (pc)'));
      await tester.pumpAndSettle();

      // Label should update
      expect(find.text('Price / pc'), findsOneWidget);

      // Tap 'Per Kilogram (kg)'
      await tester.tap(find.text('Per Kilogram (kg)'));
      await tester.pumpAndSettle();

      // Label should update
      expect(find.text('Price / kg'), findsOneWidget);
    },
  );
}
