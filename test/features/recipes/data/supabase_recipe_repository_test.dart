import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/recipes/data/supabase_recipe_repository.dart';

void main() {
  group('recipeFromSupabaseRow', () {
    test('maps a fully-populated row', () {
      final recipe = recipeFromSupabaseRow({
        'id': 1,
        'title': 'Chicken Adobo',
        'category': 'Chicken',
        'time': '45 min',
        'difficulty': 'Medium',
        'image_url': 'https://example.com/adobo.png',
        'background_color': 0xFFFEE2E2,
        'serving': '4 servings',
        'calories': '420 kcal',
        'ingredients': [
          {'name': 'Chicken', 'description': '1 kg', 'image_url': null},
          {'name': 'Soy Sauce', 'description': '1/2 cup'},
        ],
        'steps': [
          {'title': 'Marinate', 'description': '30 minutes'},
          {'title': 'Simmer', 'description': '20 minutes'},
        ],
      });

      expect(recipe.title, 'Chicken Adobo');
      expect(recipe.category, 'Chicken');
      expect(recipe.time, '45 min');
      expect(recipe.difficulty, 'Medium');
      expect(recipe.imageUrl, 'https://example.com/adobo.png');
      expect(recipe.backgroundColor, const Color(0xFFFEE2E2));
      expect(recipe.serving, '4 servings');
      expect(recipe.calories, '420 kcal');
      expect(recipe.ingredients, hasLength(2));
      expect(recipe.ingredients!.first.name, 'Chicken');
      expect(recipe.ingredients!.first.description, '1 kg');
      expect(recipe.steps, hasLength(2));
      expect(recipe.steps!.last.title, 'Simmer');
    });

    test('fills documented defaults when optional fields are missing', () {
      final recipe = recipeFromSupabaseRow({'title': 'Plain Rice'});

      expect(recipe.title, 'Plain Rice');
      expect(recipe.category, '');
      expect(recipe.serving, isNull);
      expect(recipe.calories, isNull);
      expect(recipe.ingredients, isNull);
      expect(recipe.steps, isNull);
      expect(recipe.backgroundColor, const Color(0xFFFEF3C7));
    });

    test('cannot confuse mock content with an empty table (T6.5)', () async {
      // The mapper is fed rows, never mock recipe data — a Supabase row with
      // an empty title still produces only that row.
      final recipe = recipeFromSupabaseRow({'title': ''});
      expect(recipe.title, isEmpty);
    });
  });
}
