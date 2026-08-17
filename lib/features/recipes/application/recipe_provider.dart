import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/features/recipes/data/mock_recipe_repository.dart';
import 'package:palengkego/features/recipes/data/recipe_repository.dart';
import 'package:palengkego/features/recipes/data/supabase_recipe_repository.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';

/// Single explicit backend switch for recipe content.
///
/// Supabase mode (URL + anon key supplied) reads the public `recipes` table;
/// dev/test/mock mode serves [MockRecipeRepository].
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client != null) {
    return SupabaseRecipeRepository(client);
  }
  return MockRecipeRepository();
});

/// Resolves the full recipe list through the active repository so async
/// backends (Supabase) and UIs share one loading state.
final allRecipesProvider = FutureProvider<List<Recipe>>((ref) {
  return ref.watch(recipeRepositoryProvider).getRecipes();
});
