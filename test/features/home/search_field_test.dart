import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:palengkego/features/home/presentation/widgets/search_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SearchField shows product results and clears the query', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(padding: EdgeInsets.all(20), child: SearchField()),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'mango');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Sweet Mangoes'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Sweet Mangoes'), findsNothing);

    // Flush any pending focus/unfocus debounce timers.
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('SearchField debounces rapid typing to the final query', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(padding: EdgeInsets.all(20), child: SearchField()),
          ),
        ),
      ),
    );

    final field = find.byType(TextField);
    await tester.enterText(field, 'm');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'man');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'mango');
    await tester.pump(const Duration(milliseconds: 100));

    // Debounce window (200ms from final keystroke) has not elapsed yet.
    expect(find.text('Sweet Mangoes'), findsNothing);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('Sweet Mangoes'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
  });
}
