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

  testWidgets('Got it closes a popup and records its acknowledgement', (
    tester,
  ) async {
    final popup = SystemAnnouncement(
      announcementId: 'popup-1',
      title: 'Service update',
      body: 'Please review this update.',
      targetAudience: AnnouncementAudience.customers,
      createdAt: DateTime(2026, 10, 1),
      showAsPopup: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => PriceMonitoringPopupDialog.show(context, popup),
              child: const Text('Open popup'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open popup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(
        '${AnnouncementPopupDialog.prefKeyDismissedPopupPrefix}popup-1',
      ),
      isTrue,
    );
    expect(find.text('Service update'), findsNothing);
  });

  test('remembers a popup only after the user acknowledges it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(
      prefs.getBool(
        '${AnnouncementPopupDialog.prefKeyDismissedPopupPrefix}ann-1',
      ),
      isNull,
    );

    await AnnouncementPopupDialog.markDismissed(
      sampleAnnouncement1.announcementId,
    );

    expect(
      prefs.getBool(
        '${AnnouncementPopupDialog.prefKeyDismissedPopupPrefix}ann-1',
      ),
      isTrue,
    );
  });
}
