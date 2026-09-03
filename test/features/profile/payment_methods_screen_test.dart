import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/checkout/presentation/pages/payment_methods_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PaymentMethodsScreen renders all payment options with connect/disconnect status', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: PaymentMethodsScreen(isManageMode: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment Methods'), findsOneWidget);
    expect(find.text('Connected Payment Options'), findsOneWidget);
    expect(find.text('Cash on Delivery'), findsOneWidget);
    expect(find.text('GCash'), findsOneWidget);
    expect(find.text('PayMaya'), findsOneWidget);
    expect(find.text('Credit / Debit Card'), findsOneWidget);

    // GCash is connected by default
    expect(find.text('Disconnect'), findsOneWidget);
    // Maya has Connect button, Card displays Coming Soon
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Coming Soon'), findsOneWidget);
  });

  testWidgets('Tapping Credit / Debit Card displays coming soon notification', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: PaymentMethodsScreen(isManageMode: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Credit / Debit Card'));
    await tester.pumpAndSettle();

    expect(find.text('Credit / Debit Card payment coming soon!'), findsOneWidget);
  });

  testWidgets('Tapping Disconnect shows confirmation dialog', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: PaymentMethodsScreen(isManageMode: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Disconnect on GCash
    final disconnectBtn = find.text('Disconnect');
    expect(disconnectBtn, findsOneWidget);
    await tester.tap(disconnectBtn);
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('Disconnect GCash?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect GCash?'), findsNothing);
  });
}
