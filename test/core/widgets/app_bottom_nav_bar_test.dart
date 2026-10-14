import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/widgets/app_bottom_nav_bar.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_bottom_nav.dart';

void main() {
  group('AppBottomNavBar sliding indicator tests', () {
    testWidgets('renders all 5 tabs and slides indicator on index change', (
      tester,
    ) async {
      int selectedIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (context, setState) {
                return AppBottomNavBar(
                  selectedIndex: selectedIndex,
                  onTap: (index) {
                    setState(() => selectedIndex = index);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Market'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('Cart'), findsOneWidget);

      final indicatorFinder = find.byKey(const Key('nav_sliding_indicator'));
      expect(indicatorFinder, findsOneWidget);

      final initialX = tester.getTopLeft(indicatorFinder).dx;

      // Tap Market tab
      await tester.tap(find.text('Market'));
      await tester.pump();

      // Mid-animation
      await tester.pump(const Duration(milliseconds: 100));
      final midX = tester.getTopLeft(indicatorFinder).dx;
      expect(midX, greaterThan(initialX));

      // Finish animation
      await tester.pumpAndSettle();
      final settledX = tester.getTopLeft(indicatorFinder).dx;
      expect(settledX, greaterThan(midX));
      expect(selectedIndex, equals(1));
    });

    testWidgets(
      'keeps indicator visible for persistent tabs when isCartAction is true, fades on cart',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: AppBottomNavBar(
                selectedIndex: 0,
                isCartAction: true,
                onTap: (_) {},
              ),
            ),
          ),
        );

        final opacityFinder = find.byType(AnimatedOpacity);
        expect(opacityFinder, findsOneWidget);
        var opacityWidget = tester.widget<AnimatedOpacity>(opacityFinder);
        expect(opacityWidget.opacity, equals(1.0));

        // When selectedIndex is 4 (cart) and isCartAction is true
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: AppBottomNavBar(
                selectedIndex: 4,
                isCartAction: true,
                onTap: (_) {},
              ),
            ),
          ),
        );
        opacityWidget = tester.widget<AnimatedOpacity>(opacityFinder);
        expect(opacityWidget.opacity, equals(0.0));
      },
    );
  });

  group('VendorDashboardBottomNav sliding indicator tests', () {
    testWidgets('renders all 4 tabs and slides indicator on select', (
      tester,
    ) async {
      int selectedIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (context, setState) {
                return VendorDashboardBottomNav(
                  selectedIndex: selectedIndex,
                  onSelect: (index) {
                    setState(() => selectedIndex = index);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      final indicatorFinder = find.byKey(const Key('vendor_nav_sliding_indicator'));
      expect(indicatorFinder, findsOneWidget);

      final initialX = tester.getTopLeft(indicatorFinder).dx;

      // Tap Orders tab
      await tester.tap(find.text('Orders'));
      await tester.pump();

      // Mid-animation
      await tester.pump(const Duration(milliseconds: 100));
      final midX = tester.getTopLeft(indicatorFinder).dx;
      expect(midX, greaterThan(initialX));

      // Finish animation
      await tester.pumpAndSettle();
      final settledX = tester.getTopLeft(indicatorFinder).dx;
      expect(settledX, greaterThan(midX));
      expect(selectedIndex, equals(1));
    });
  });
}
