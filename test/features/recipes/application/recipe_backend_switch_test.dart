import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/features/recipes/application/recipe_provider.dart';
import 'package:palengkego/features/recipes/data/mock_recipe_repository.dart';

void main() {
  group('recipeRepositoryProvider backend switch', () {
    test('without Supabase credentials resolves to the mock recipes', () {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(recipeRepositoryProvider),
        isA<MockRecipeRepository>(),
      );
      expect(container.read(supabaseConfiguredProvider), isFalse);
    });

    test('allRecipesProvider streams the active repository content', () async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
          ),
        ],
      );
      addTearDown(container.dispose);

      final recipes = await container.read(allRecipesProvider.future);
      expect(recipes, isNotEmpty);
    });
  });
}
