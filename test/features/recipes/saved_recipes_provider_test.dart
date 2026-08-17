import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/recipes/application/saved_recipes_provider.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SavedRecipesNotifier Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    const testRecipe = Recipe(
      id: 'sinigang-na-hipon',
      title: 'Sinigang na Hipon',
      category: 'Seafood',
      time: '30 min',
      difficulty: 'Easy',
      imageUrl:
          'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=400&h=250&fit=crop',
      backgroundColor: Color(0xFFE0F2FE),
    );

    test('starts with an empty saved list', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await container.read(savedRecipesProvider.future);
      expect(state, isEmpty);
    });

    test('restores saved titles from SharedPreferences on init', () async {
      SharedPreferences.setMockInitialValues({
        'saved_recipes_titles': ['Sinigang na Hipon'],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await container.read(savedRecipesProvider.future);
      expect(state, hasLength(1));
      expect(state.first.title, 'Sinigang na Hipon');
    });

    test('toggles saving a recipe (saves a new recipe)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(savedRecipesProvider.notifier);
      await container.read(savedRecipesProvider.future);
      expect(notifier.isSaved(testRecipe), isFalse);

      notifier.toggleSave(testRecipe);

      final state = container.read(savedRecipesProvider).value ?? [];
      expect(state, hasLength(1));
      expect(state.first.title, 'Sinigang na Hipon');
      expect(notifier.isSaved(testRecipe), isTrue);
    });

    test('toggles saving a recipe (removes an already saved recipe)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(savedRecipesProvider.notifier);
      await container.read(savedRecipesProvider.future);
      notifier.toggleSave(testRecipe);
      expect(notifier.isSaved(testRecipe), isTrue);

      notifier.toggleSave(testRecipe);

      final state = container.read(savedRecipesProvider).value ?? [];
      expect(state, isEmpty);
      expect(notifier.isSaved(testRecipe), isFalse);
    });
  });
}
