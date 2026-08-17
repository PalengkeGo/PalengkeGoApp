import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recipe_category_chips.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recipe_list_card.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recipe_stats_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _adobo = Recipe(
  id: 'adobong-manok',
  title: 'Adobong Manok',
  category: 'Beef',
  time: '45 min',
  difficulty: 'Easy',
  imageUrl: 'https://example.com/adobo.jpg',
  backgroundColor: Color(0xFFFEF3C7),
);

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RecipeListCard', () {
    testWidgets('renders title, category, time, difficulty and fires onTap',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          RecipeListCard(recipe: _adobo, onTap: () => tapped = true),
        ),
      );

      expect(find.text('Adobong Manok'), findsOneWidget);
      expect(find.text('Beef'), findsOneWidget);
      expect(find.text('45 min'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);

      await tester.tap(find.text('Adobong Manok'));
      expect(tapped, isTrue);
    });

    testWidgets('heart toggles save state and announces via snackbar',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          RecipeListCard(recipe: _adobo, onTap: () {}),
        ),
      );

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(
        find.text('Added "Adobong Manok" to Cookbook.'),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(
        find.text('Removed "Adobong Manok" from Cookbook.'),
        findsOneWidget,
      );
    });
  });

  group('RecipeStatsRow', () {
    testWidgets('falls back to default serving and energy values',
        (tester) async {
      await tester.pumpWidget(_wrap(const RecipeStatsRow(recipe: _adobo)));

      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('45 min'), findsOneWidget);
      expect(find.text('SERVING'), findsOneWidget);
      expect(find.text('4 Persons'), findsOneWidget);
      expect(find.text('ENERGY'), findsOneWidget);
      expect(find.text('320 kcal'), findsOneWidget);
    });

    testWidgets('shows explicit serving and calories', (tester) async {
      const recipe = Recipe(
        id: 'sinigang',
        title: 'Sinigang',
        category: 'Seafood',
        time: '60 min',
        difficulty: 'Medium',
        serving: '6 Persons',
        calories: '450 kcal',
        imageUrl: 'https://example.com/sinigang.jpg',
        backgroundColor: Color(0xFFFFF7ED),
      );

      await tester.pumpWidget(_wrap(const RecipeStatsRow(recipe: recipe)));

      expect(find.text('6 Persons'), findsOneWidget);
      expect(find.text('450 kcal'), findsOneWidget);
      expect(find.text('4 Persons'), findsNothing);
    });
  });

  group('RecipeCategoryChips', () {
    testWidgets('renders every category and reports selections',
        (tester) async {
      final selections = <String>[];
      await tester.pumpWidget(
        _wrap(
          RecipeCategoryChips(
            categories: ['All', 'Beef', 'Vegetables', 'Seafood'],
            selectedCategory: 'Beef',
            onSelect: selections.add,
          ),
        ),
      );

      for (final category in ['All', 'Beef', 'Vegetables', 'Seafood']) {
        expect(find.text(category), findsOneWidget);
      }

      await tester.tap(find.text('Vegetables'));
      expect(selections, ['Vegetables']);
    });
  });
}