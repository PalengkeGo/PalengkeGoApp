import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recipe_steps_list.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recipe_stats_row.dart';

const _recipe = Recipe(
  id: 'adobong-manok',
  title: 'Adobong Manok',
  category: 'Beef',
  time: '45 min',
  difficulty: 'Easy',
  serving: '4 Persons',
  calories: '480 kcal',
  imageUrl: 'https://example.com/adobo.jpg',
  backgroundColor: Color(0xFFFEF3C7),
  steps: [
    RecipeStep(
      title: 'Step 1',
      description: 'Sear the chicken in a hot pan until lightly browned.',
    ),
    RecipeStep(
      title: 'Step 2',
      description:
          'Simmer with soy sauce, vinegar, garlic and bay leaves for 30 minutes.',
    ),
  ],
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recipe stats row golden', (tester) async {
    await _pump(
      tester,
      const SizedBox(
        width: 400,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: RecipeStatsRow(recipe: _recipe),
        ),
      ),
    );

    await expectLater(
      find.byType(RecipeStatsRow),
      matchesGoldenFile('goldens/recipe_stats_row.png'),
    );
  });

  testWidgets('recipe steps list golden', (tester) async {
    await _pump(
      tester,
      const SizedBox(
        width: 400,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: RecipeStepsList(recipe: _recipe),
        ),
      ),
    );

    await expectLater(
      find.byType(RecipeStepsList),
      matchesGoldenFile('goldens/recipe_steps_list.png'),
    );
  });
}
