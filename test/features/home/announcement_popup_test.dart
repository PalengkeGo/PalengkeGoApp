import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/home/domain/system_announcement.dart';
import 'package:palengkego/features/home/presentation/widgets/announcement_popup_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final sampleAnnouncement1 = SystemAnnouncement(
    announcementId: 'ann-1',
    title: 'Grand Market Day Sale',
    body: 'Fresh vegetables and fruits at 20% off today only!',
    targetAudience: AnnouncementAudience.all,
    createdAt: DateTime(2026, 10, 1),
  );

  final sampleAnnouncement2 = SystemAnnouncement(
    announcementId: 'ann-2',
    title: 'Free Delivery Weekend',
    body: 'Enjoy zero delivery fees on orders above 500 pesos.',
    targetAudience: AnnouncementAudience.customers,
    createdAt: DateTime(2026, 10, 1),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders announcement title, body, and dismisses on Got it tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AnnouncementPopupDialog.show(
                context,
                announcements: [sampleAnnouncement1],
              ),
              child: const Text('Open Popup'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Popup'));
    await tester.pumpAndSettle();

    expect(find.text('Grand Market Day Sale'), findsOneWidget);
    expect(
      find.text('Fresh vegetables and fruits at 20% off today only!'),
      findsOneWidget,
    );
    expect(find.text('ANNOUNCEMENT'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Grand Market Day Sale'), findsNothing);
  });

  testWidgets('supports paging through multiple announcements', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AnnouncementPopupDialog.show(
                context,
                announcements: [sampleAnnouncement1, sampleAnnouncement2],
              ),
              child: const Text('Open Popup'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Popup'));
    await tester.pumpAndSettle();

    expect(find.text('Grand Market Day Sale'), findsOneWidget);

    // Drag to swipe to second announcement
    await tester.drag(find.text('Grand Market Day Sale'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Free Delivery Weekend'), findsOneWidget);
  });

  test('records daily popup date in SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final today =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    expect(
      prefs.getString(AnnouncementPopupDialog.prefKeyLastPopupDate),
      isNull,
    );

    await prefs.setString(AnnouncementPopupDialog.prefKeyLastPopupDate, today);

    expect(
      prefs.getString(AnnouncementPopupDialog.prefKeyLastPopupDate),
      today,
    );
  });
}
