import 'package:flutter/material.dart';
import 'package:palengkego/features/recipes/data/recipe_repository.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pure mapping from a Supabase `recipes` row to a [Recipe].
///
/// Table contract (public read-only RLS):
///   title, category, time, difficulty, image_url,
///   serving (text|null), calories (text|null),
///   background_color (int ARGB, nullable),
///   ingredients (jsonb [{name, description, image_url?}]),
///   steps (jsonb [{title, description}])
///
/// Missing/absent fields degrade to documented defaults — never to mock
/// recipe content (T6.5).
Recipe recipeFromSupabaseRow(Map<String, dynamic> row) {
  final rawId = row['id'];
  return Recipe(
    id: rawId is int
        ? rawId.toString()
        : rawId as String? ?? row['title'] as String? ?? '',
    title: row['title'] as String? ?? '',
    category: row['category'] as String? ?? '',
    time: row['time'] as String? ?? '',
    difficulty: row['difficulty'] as String? ?? '',
    imageUrl: row['image_url'] as String? ?? '',
    backgroundColor: Color(row['background_color'] as int? ?? 0xFFFEF3C7),
    serving: row['serving'] as String?,
    calories: row['calories'] as String?,
    ingredients: (row['ingredients'] as List?)
        ?.map(
          (e) => RecipeIngredient(
            name: (e as Map)['name'] as String? ?? '',
            description: (e)['description'] as String? ?? '',
            imageUrl: e['image_url'] as String?,
          ),
        )
        .toList(),
    steps: (row['steps'] as List?)
        ?.map(
          (s) => RecipeStep(
            title: (s as Map)['title'] as String? ?? '',
            description: s['description'] as String? ?? '',
          ),
        )
        .toList(),
  );
}

/// Supabase-backed [RecipeRepository] — read-only public content.
///
/// T6.5 contract: if the table is missing or unreachable, every read returns
/// the documented empty state (`[]`, and [getFeaturedRecipe] / [getMoreRecipes]
/// throw a clear [StateError]) — never unrelated mock rows.
class SupabaseRecipeRepository implements RecipeRepository {
  SupabaseRecipeRepository(this._client);

  static const _table = 'recipes';

  final SupabaseClient _client;

  @override
  Future<List<Recipe>> getRecipes() async {
    try {
      final response = await _client.from(_table).select().order('id');
      return (response as List)
          .map(
            (row) =>
                recipeFromSupabaseRow((row as Map).cast<String, dynamic>()),
          )
          .toList();
    } catch (e) {
      return <Recipe>[];
    }
  }

  @override
  Future<Recipe> getFeaturedRecipe() async {
    final recipes = await getRecipes();
    if (recipes.isEmpty) {
      throw StateError('recipes table is empty or unreachable');
    }
    return recipes.first;
  }

  @override
  Future<List<Recipe>> getMoreRecipes() async {
    final recipes = await getRecipes();
    return recipes.isEmpty ? <Recipe>[] : recipes.skip(1).toList();
  }
}
