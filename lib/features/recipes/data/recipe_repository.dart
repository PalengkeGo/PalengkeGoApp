import 'package:palengkego/features/recipes/domain/recipe.dart';

/// Content repository for recipes.
///
/// Mock mode returns static content instantly; Supabase mode streams the
/// public `recipes` table over the network, so every method is async.
abstract class RecipeRepository {
  Future<List<Recipe>> getRecipes();

  Future<Recipe> getFeaturedRecipe();

  Future<List<Recipe>> getMoreRecipes();
}
