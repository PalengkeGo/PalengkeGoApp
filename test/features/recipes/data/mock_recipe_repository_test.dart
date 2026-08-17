import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/recipes/data/mock_recipe_repository.dart';

void main() {
  group('MockRecipeRepository', () {
    test('returns featured recipe first', () async {
      final repository = MockRecipeRepository();

      final recipe = await repository.getFeaturedRecipe();

      expect(recipe.title, 'Sinigang na Hipon');
      expect(recipe.category, 'Seafood');
      expect(recipe.time, '30 min');
      expect(recipe.backgroundColor, const Color(0xFFE0F2FE));
    });

    test('returns all recipes in display order', () async {
      final repository = MockRecipeRepository();

      final recipes = await repository.getRecipes();

      expect(recipes, hasLength(7));
      expect(recipes.first.title, 'Sinigang na Hipon');
      expect(recipes.last.title, 'Turon (Banana Spring Rolls)');
    });

    test('returns more recipes without the featured recipe', () async {
      final repository = MockRecipeRepository();

      final recipes = await repository.getMoreRecipes();

      expect(recipes, hasLength(6));
      expect(
        recipes.any((recipe) => recipe.title == 'Sinigang na Hipon'),
        isFalse,
      );
      expect(recipes.first.title, 'Chicken Adobo');
    });

    test('creates details map compatible with recipe details screen', () async {
      final repository = MockRecipeRepository();

      final recipe = await repository.getFeaturedRecipe();
      final details = recipe.toDetailsMap();

      expect(details['name'], 'Sinigang na Hipon');
      expect(details['imageUrl'], recipe.imageUrl);
      expect(details['description'], 'Seafood • Easy • 30 min');
      expect(details['time'], '30 min');
    });
  });
}
