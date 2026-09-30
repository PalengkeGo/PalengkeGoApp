import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/vendors/presentation/widgets/closing_soon_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/vendors/domain/closing_time.dart';
import 'package:palengkego/features/vendors/domain/day_schedule.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';
import 'package:palengkego/features/vendors/presentation/widgets/profile/vendor_reviews_carousel.dart';

void main() {
  testWidgets('saved hours produce a notice only for the matching open stall', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketSchedulesProvider.overrideWith(
            (ref) async => {
              'stall': [const DaySchedule(name: 'Monday', closeTime: '18:00')],
            },
          ),
          closingClockProvider.overrideWith(
            (ref) => Stream.value(DateTime.parse('2026-09-28T09:15:00Z')),
          ),
        ],
        child: const MaterialApp(
          home: Column(
            children: [
              ClosingSoonNotice(vendorId: 'stall', isOpen: true),
              ClosingSoonNotice(vendorId: 'other', isOpen: true),
              ClosingSoonNotice(vendorId: 'stall', isOpen: false),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Closes in 45 min'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('one-hour warning follows Philippine hours and manual closure', () {
    const schedule = [
      DaySchedule(name: 'Monday', openTime: '06:00', closeTime: '18:00'),
    ];
    int? remaining(String utc, {bool open = true}) =>
        minutesUntilClosing(schedule, DateTime.parse(utc), isOpen: open);
    expect(remaining('2026-09-28T08:59:59Z'), isNull);
    expect(remaining('2026-09-28T09:00:00Z'), 60);
    expect(remaining('2026-09-28T09:30:01Z'), 30);
    expect(remaining('2026-09-28T09:59:59Z'), 1);
    expect(remaining('2026-09-28T10:00:00Z'), isNull);
    expect(remaining('2026-09-28T09:30:00Z', open: false), isNull);
    expect(remaining('2026-09-29T09:30:00Z'), isNull);
  });
  test('overnight shifts, closed days and invalid hours', () {
    final now = DateTime.parse('2026-09-28T17:30:00Z'); // Tuesday 01:30
    expect(
      minutesUntilClosing(
        const [
          DaySchedule(
            name: 'Monday',
            openTime: '22:00:00',
            closeTime: '02:00:00',
          ),
        ],
        now,
        isOpen: true,
      ),
      30,
    );
    for (final day in [
      const DaySchedule(name: 'Tuesday', isOpen: false, closeTime: '02:00'),
      const DaySchedule(name: 'Tuesday', openTime: 'bad', closeTime: '02:00'),
      const DaySchedule(name: 'Tuesday', openTime: '02:00', closeTime: '02:00'),
    ]) {
      expect(minutesUntilClosing([day], now, isOpen: true), isNull);
    }
  });

  final reviews = List.generate(
    2,
    (i) => VendorReview(
      id: '$i',
      vendorId: 'stall',
      customerId: '$i',
      customerName: 'A customer with a very long name that must fit',
      rating: 5,
      comment: 'Fresh produce',
      date: DateTime(2026),
    ),
  );
  Widget app({bool reduced = false, List<VendorReview>? items}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(body: VendorReviewsCarousel(reviews: items ?? reviews)),
    ),
  );
  double offset(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
  Future<void> frames(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets(
    'reviews move steadily across repeated content and resume at dragged position',
    (tester) async {
      await tester.pumpWidget(app());
      await frames(tester, 1800); // Beyond the old 24-second snap.
      expect(offset(tester), closeTo(576, 1));
      await tester.drag(find.byType(ListView), const Offset(-100, 0));
      await tester.pump(const Duration(seconds: 2));
      final dragged = offset(tester);
      await tester.pump(const Duration(seconds: 4));
      await frames(tester, 2);
      expect(offset(tester), closeTo(dragged, 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'reduced motion and single reviews stay still; new reviews start scrolling',
    (tester) async {
      await tester.pumpWidget(app(reduced: true));
      await frames(tester, 10);
      expect(offset(tester), 0);
      await tester.pumpWidget(app(items: [reviews.first]));
      await frames(tester, 10);
      expect(offset(tester), 0);
      await tester.pumpWidget(app());
      await frames(tester, 10);
      expect(offset(tester), greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
