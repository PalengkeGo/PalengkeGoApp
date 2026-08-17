import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_earnings_screen.dart';

class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(this.initialUser);

  final AppUser? initialUser;

  @override
  AppUser? build() => initialUser;
}

void main() {
  Future<void> pumpEarningsScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => TestAuthNotifier(MockUsers.vendor)),
        ],
        child: const MaterialApp(home: VendorEarningsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('VendorEarningsScreen export UI', () {
    testWidgets('opens export sheet with PDF and Excel actions', (
      tester,
    ) async {
      await pumpEarningsScreen(tester);

      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Export Sales Report'), findsOneWidget);
      expect(find.text('Export as PDF'), findsOneWidget);
      expect(find.text('Export as Excel'), findsOneWidget);
    });

    testWidgets('switching periods updates visible totals', (tester) async {
      await pumpEarningsScreen(tester);

      expect(find.textContaining('2,450.00'), findsOneWidget);

      await tester.tap(find.text('Week'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('12,450.00'), findsOneWidget);

      await tester.tap(find.text('Month'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('48,200.00'), findsOneWidget);
    });
  });
}
