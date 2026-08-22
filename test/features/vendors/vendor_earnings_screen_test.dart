import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/vendors/application/vendor_earnings_provider.dart';
import 'package:palengkego/features/vendors/domain/sales_summary.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_earnings_screen.dart';

class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(this.initialUser);

  final AppUser? initialUser;

  @override
  AppUser? build() => initialUser;
}

void main() {
  // Deterministic daily rollups relative to "today" so the computed totals
  // are exactly predictable:
  //   today=100, yesterday=40          → Today: ₱100.00 (+₱60.00)
  //   last 7 days = 100+40+5×10 = 190  → Week: ₱190.00
  //   prev 7 days = 7×5 = 35
  //   days 14–27   = 14×1 = 14         → Month (28d): 190+35+14 = 239
  List<SalesSummary> fixtureSummaries() {
    final now = DateTime.now();
    DateTime day(int back) =>
        DateTime(now.year, now.month, now.day).subtract(Duration(days: back));
    SalesSummary s(int back, double revenue) => SalesSummary(
          summaryId: 'd$back',
          stallId: 'stall-v',
          date: day(back),
          totalOrders: 1,
          totalRevenue: revenue,
          totalItemsSold: 1,
        );
    return [
      s(0, 100),
      s(1, 40),
      for (var i = 2; i < 7; i++) s(i, 10),
      for (var i = 7; i < 14; i++) s(i, 5),
      for (var i = 14; i < 28; i++) s(i, 1),
    ];
  }

  Future<void> pumpEarningsScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => TestAuthNotifier(MockUsers.vendor)),
          vendorDailySalesProvider.overrideWith((ref) => fixtureSummaries()),
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

    testWidgets('shows REAL computed totals per period (no fabrication)', (
      tester,
    ) async {
      await pumpEarningsScreen(tester);

      // Today = today's rollup only; change vs yesterday is computed.
      expect(find.text('₱100.00'), findsOneWidget);
      expect(find.textContaining('₱60.00 vs yesterday'), findsOneWidget);

      await tester.tap(find.text('Week'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('₱190.00'), findsOneWidget);

      await tester.tap(find.text('Month'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('₱239.00'), findsOneWidget);
    });

    testWidgets('renders honest zeros when there are no sales', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => TestAuthNotifier(MockUsers.vendor)),
            vendorDailySalesProvider.overrideWith((ref) => const []),
          ],
          child: const MaterialApp(home: VendorEarningsScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('₱0.00'), findsOneWidget);
      expect(find.text('No completed sales yet'), findsOneWidget);
    });
  });
}
