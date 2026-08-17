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

  testWidgets('desktop 800dp centers the app at the 480 breakpoint', (
    tester,
  ) async {
    await pumpAtSize(tester, const Size(800, 600));
    final subject = tester.getRect(find.byKey(const Key('subject')));
    expect(subject.width, 480);
    expect(subject.left, (800 - 480) / 2);
  });

  testWidgets('desktop 1024dp centers the app at the 480 breakpoint', (
    tester,
  ) async {
    await pumpAtSize(tester, const Size(1024, 768));
    final subject = tester.getRect(find.byKey(const Key('subject')));
    expect(subject.width, 480);
    expect(subject.left, (1024 - 480) / 2);
  });
}
