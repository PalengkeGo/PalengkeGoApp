import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/widgets/responsive_wrapper.dart';

void main() {
  Future<void> pumpAtSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveWrapper(
          child: SizedBox(key: Key('subject'), width: double.infinity),
        ),
      ),
    );
  }

  testWidgets('mobile 360dp fills the width, no forced minimum', (
    tester,
  ) async {
    await pumpAtSize(tester, const Size(360, 740));
    final subject = tester.getRect(find.byKey(const Key('subject')));
    expect(subject.left, 0);
    expect(subject.width, 360);
  });

  testWidgets('mobile 390dp fills the width, no forced minimum', (
    tester,
  ) async {
    await pumpAtSize(tester, const Size(390, 844));
    final subject = tester.getRect(find.byKey(const Key('subject')));
    expect(subject.left, 0);
    expect(subject.width, 390);
  });

  testWidgets('mobile 430dp fills the width, no forced minimum', (
    tester,
  ) async {
    await pumpAtSize(tester, const Size(430, 932));
    final subject = tester.getRect(find.byKey(const Key('subject')));
    expect(subject.left, 0);
    expect(subject.width, 430);
  });


  testWidgets('Floating SnackBar with bottom nav renders without off-screen exception', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ResponsiveWrapper(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test SnackBar'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
          bottomNavigationBar: Container(
            height: 60,
            color: Colors.blue,
            child: const Center(child: Text('BottomNav')),
          ),
        ),
      ),
    );

    // Tap to show the floating SnackBar
    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify SnackBar rendered cleanly without throwing off-screen exception
    expect(find.text('Test SnackBar'), findsOneWidget);
  });
}
