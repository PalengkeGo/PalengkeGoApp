import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/features/home/presentation/widgets/market_search_results.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';

void main() {
  testWidgets('empty market search waits for refreshed catalog', (
    tester,
  ) async {
    final refreshed = Completer<List<MarketVendor>>();
    var requests = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allVendorsProvider.overrideWith((ref) async {
            ref.watch(dataRefreshSignal);
            requests++;
            return requests == 1 ? [] : refreshed.future;
          }),
          allProductsProvider.overrideWith((ref) async {
            ref.watch(dataRefreshSignal);
            return [];
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarketCombinedSearchResults(query: 'fruit')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No results for "fruit"'), findsOneWidget);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 400));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(requests, 2);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    expect(find.text('No results for "fruit"'), findsOneWidget);

    refreshed.complete(const [
      MarketVendor(
        id: 'test',
        name: 'Fresh fruit',
        category: 'Fruits',
        rating: 5,
        isVerified: true,
        distance: '',
        imageUrl: '',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Fresh fruit'), findsOneWidget);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
