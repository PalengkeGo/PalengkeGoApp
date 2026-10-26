import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/auth/presentation/widgets/email_verification_reminder_dialog.dart';

void main() {
  testWidgets('reminder stays open until Got it is pressed', (tester) async {
    var acknowledged = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => EmailVerificationReminderDialog(
                    email: 'customer@example.com',
                    onGotIt: () async {
                      acknowledged = true;
                    },
                    onCheckVerification: () async => false,
                  ),
                ),
                child: const Text('Open reminder'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open reminder'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to PalengkeGo!'), findsOneWidget);
    expect(find.text('customer@example.com'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(acknowledged, isTrue);
    expect(find.text('Welcome to PalengkeGo!'), findsNothing);
  });
}
