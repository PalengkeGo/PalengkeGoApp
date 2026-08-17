import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/vendors/presentation/widgets/vendor_screen_header.dart';

void main() {
  testWidgets('VendorScreenHeader golden test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VendorScreenHeader(title: 'My Stall')),
      ),
    );

    await expectLater(
      find.byType(VendorScreenHeader),
      matchesGoldenFile('goldens/vendor_screen_header.png'),
    );
  });
}
