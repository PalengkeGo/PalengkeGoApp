import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';
import 'package:palengkego/features/recipes/application/recipe_provider.dart';

class SavedRecipesNotifier extends AsyncNotifier<List<Recipe>> {
  static const _key = 'saved_recipes_ids';
  static const _legacyTitlesKey = 'saved_recipes_titles';

  String _userKey(String? uid) {
    if (uid != null && uid.isNotEmpty) {
      return '${_key}_$uid';
    }
    return _key;
  }

  @override
  Future<List<Recipe>> build() async {
    final user = ref.watch(authProvider);
    final uid = user?.uid;
    final prefs = await SharedPreferences.getInstance();
    final userKey = _userKey(uid);
    final savedIds = prefs.getStringList(userKey) ??
        (uid != null ? prefs.getStringList(_key) : null) ??
        prefs.getStringList(_key) ??
        [];
    if (savedIds.isNotEmpty) {
      final allRecipes = await ref.read(recipeRepositoryProvider).getRecipes();
      final restored = allRecipes
          .where((r) => savedIds.contains(r.id))
          .toList();
      // Drop ids that no longer resolve to a recipe.
      if (restored.length != savedIds.length) {
        await _save(restored, uid);
      }
      return restored;
    }

    // One-time migration from the legacy title-based key.
    final legacyTitles = prefs.getStringList(_legacyTitlesKey) ?? [];
    if (legacyTitles.isNotEmpty) {
      final allRecipes = await ref.read(recipeRepositoryProvider).getRecipes();
      final migrated = allRecipes
          .where((r) => legacyTitles.contains(r.title))
          .toList();
      await _save(migrated, uid);
      await prefs.remove(_legacyTitlesKey);
      return migrated;
    }

    return [];
  }

  Future<void> _save(List<Recipe> recipes, [String? uid]) async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveUid = uid ?? (ref.mounted ? ref.read(authProvider)?.uid : null);
    final key = _userKey(effectiveUid);
    await prefs.setStringList(key, recipes.map((r) => r.id).toList());
  }

  bool isSaved(Recipe recipe) {
    return (state.value ?? const []).any((r) => r.id == recipe.id);
  }

  void toggleSave(Recipe recipe) {
    final current = state.value ?? const <Recipe>[];
    if (isSaved(recipe)) {
      state = AsyncData(current.where((r) => r.id != recipe.id).toList());
    } else {
      state = AsyncData([...current, recipe]);
    }
    _save(state.value ?? const []);
  }
}

final savedRecipesProvider =
    AsyncNotifierProvider<SavedRecipesNotifier, List<Recipe>>(
      SavedRecipesNotifier.new,
    );
