import 'package:flutter/material.dart';
import 'package:palengkego/core/utils/image_url_resolver.dart';
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
int _parseColor(dynamic val) {
  if (val == null) return 0xFFFEF3C7;
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String) {
    if (val.startsWith('#')) {
      final hex = val.replaceAll('#', '');
      return int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16) ??
          0xFFFEF3C7;
    }
    return int.tryParse(val) ?? 0xFFFEF3C7;
  }
  return 0xFFFEF3C7;
}

Recipe recipeFromSupabaseRow(Map<String, dynamic> row, {SupabaseClient? client}) {
  final rawId = row['id'];
  return Recipe(
    id: rawId is int
        ? rawId.toString()
        : rawId as String? ?? row['title'] as String? ?? '',
    title: row['title'] as String? ?? '',
    category: row['category'] as String? ?? '',
    time: row['time'] as String? ?? '',
    difficulty: row['difficulty'] as String? ?? '',
    imageUrl: resolveImageUrl(row['image_url'] as String?, client: client) ?? '',
    backgroundColor: Color(_parseColor(row['background_color'])),
    serving: row['serving']?.toString(),
    calories: row['calories']?.toString(),
    ingredients: (row['ingredients'] as List?)
        ?.map(
          (e) => RecipeIngredient.fromMap((e as Map).cast<String, dynamic>()),
        )
        .toList(),
    steps: (row['steps'] as List?)
        ?.map(
          (s) {
            final smap = (s as Map).cast<String, dynamic>();
            final title = smap['title']?.toString() ??
                (smap['step'] != null ? 'Step ${smap['step']}' : '');
            return RecipeStep(
              title: title,
              description: smap['description']?.toString() ?? '',
            );
          },
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
                recipeFromSupabaseRow((row as Map).cast<String, dynamic>(), client: _client),
          )
          .toList();
    } catch (e, stack) {
      assert(() {
        debugPrint('SupabaseRecipeRepository.getRecipes error: $e\n$stack');
        return true;
      }());
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
