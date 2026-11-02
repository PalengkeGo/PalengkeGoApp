import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/recipes/application/recipe_provider.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';
import 'package:palengkego/features/recipes/presentation/pages/recipes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _recipe = Recipe(
  id: 'recipe-1',
  title: 'Chicken Adobo',
  category: 'Chicken',
  time: '45 min',
  difficulty: 'Easy',
  imageUrl: '',
  backgroundColor: Color(0xFFFEF3C7),
);

class _PendingOrderService extends OrderService {
  static late Completer<List<MarketOrder>> result;

  @override
  Future<List<MarketOrder>> build() => result.future;
}

void main() {
  testWidgets('does not show locked recipes while orders are still loading', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _PendingOrderService.result = Completer<List<MarketOrder>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allRecipesProvider.overrideWith((ref) async => const [_recipe]),
          orderServiceProvider.overrideWith(_PendingOrderService.new),
        ],
        child: const MaterialApp(home: RecipesScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Locked Recipes'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    _PendingOrderService.result.complete(const []);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Locked Recipes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
