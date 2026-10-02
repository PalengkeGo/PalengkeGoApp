import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/widgets/skeleton_loading.dart';

void main() {
  group('Skeleton Loading Widgets', () {
    testWidgets('SkeletonBox renders with given dimensions and shape', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonBox(
              width: 100,
              height: 50,
              shape: BoxShape.rectangle,
            ),
          ),
        ),
      );

      final boxFinder = find.byType(SkeletonBox);
      expect(boxFinder, findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(of: boxFinder, matching: find.byType(Container)),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.rectangle);
    });

    testWidgets('VendorCardSkeleton renders top and bottom structure', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 280,
              child: VendorCardSkeleton(),
            ),
          ),
        ),
      );

      expect(find.byType(VendorCardSkeleton), findsOneWidget);
      // Multiple SkeletonBox instances representing image, badge, rating, text lines
      expect(find.byType(SkeletonBox), findsAtLeastNWidgets(5));
    });

    testWidgets('ProductCardSkeleton renders in horizontal mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductCardSkeleton(isHorizontal: true),
          ),
        ),
      );

      expect(find.byType(ProductCardSkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsAtLeastNWidgets(4));
    });

    testWidgets('ProductCardSkeleton renders in grid mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 160,
              height: 220,
              child: ProductCardSkeleton(isHorizontal: false),
            ),
          ),
        ),
      );

      expect(find.byType(ProductCardSkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsAtLeastNWidgets(3));
    });

    testWidgets('VendorCardSkeletonGrid renders correct item count', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VendorCardSkeletonGrid(itemCount: 4),
            ),
          ),
        ),
      );

      expect(find.byType(VendorCardSkeleton), findsNWidgets(4));
    });

    testWidgets('ProductCardSkeletonRow renders horizontal list of skeletons', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductCardSkeletonRow(itemCount: 3),
          ),
        ),
      );

      expect(find.byType(ProductCardSkeleton), findsNWidgets(3));
    });

    testWidgets('ProductCardSkeletonGrid renders grid of skeletons', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProductCardSkeletonGrid(itemCount: 4),
            ),
          ),
        ),
      );

      expect(find.byType(ProductCardSkeleton), findsNWidgets(4));
    });
  });
}
