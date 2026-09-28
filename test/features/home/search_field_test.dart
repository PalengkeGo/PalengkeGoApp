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

    expect(find.text('Sweet Mangoes'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Sweet Mangoes'), findsNothing);

    // Flush any pending focus/unfocus debounce timers.
    await tester.pump(const Duration(milliseconds: 300));
  });
}
