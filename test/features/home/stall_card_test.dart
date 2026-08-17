import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/home/presentation/widgets/stall_card.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_profile_screen.dart';

void main() {
  group('StallCard', () {
    testWidgets('closed stall shows a message and does not open profile', (
      tester,
    ) async {
      const closedVendor = MarketVendor(
        id: 'v3',
        name: 'Closed Fish Stall',
        category: 'Fish & Seafood',
        rating: 4.6,
        isVerified: true,
        distance: '120m',
        imageUrl: '',
        isOpen: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 280,
              child: StallCard(vendor: closedVendor),
            ),
          ),
        ),
      );

      expect(find.text('CLOSED'), findsOneWidget);

      await tester.tap(find.byType(StallCard));
      await tester.pump();

      expect(
        find.text('This stall is currently closed and will open soon.'),
        findsOneWidget,
      );
      expect(find.byType(VendorProfileScreen), findsNothing);
    });
  });
}
