import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/main.dart';
import 'package:palengkego/features/onboarding/presentation/pages/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app loads and advances past splash timer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const PalengkeGoApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.semanticLabel == 'PalengkeGo',
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
