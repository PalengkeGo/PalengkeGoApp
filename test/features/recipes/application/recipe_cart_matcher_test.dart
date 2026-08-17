import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/recipes/application/recipe_cart_matcher.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';

const _adobo = Recipe(
  id: 'adobong-manok',
  title: 'Adobong Manok',
  category: 'Chicken',
  time: '45 min',
  difficulty: 'Easy',
  imageUrl: 'https://example.com/adobo.jpg',
  backgroundColor: Color(0xFFFEF3C7),
  ingredients: [
    RecipeIngredient(name: 'Chicken', description: '1 whole, cut into pieces'),
    RecipeIngredient(name: 'Soy Sauce', description: '1/2 cup'),
    RecipeIngredient(name: 'Vinegar', description: '1/3 cup'),
  ],
);

const _sinigang = Recipe(
  id: 'sinigang-na-bangus',
  title: 'Sinigang na Bangus',
  category: 'Seafood',
  time: '60 min',
  difficulty: 'Medium',
  imageUrl: 'https://example.com/sinigang.jpg',
  backgroundColor: Color(0xFFFFF7ED),
  ingredients: [
    RecipeIngredient(name: 'Bangus (Milkfish)', description: '1 large'),
    RecipeIngredient(name: 'Tamarind', description: '1/2 cup mix'),
    RecipeIngredient(name: 'Kangkong', description: '2 bunches'),
  ],
);

const _noIngredients = Recipe(
  id: 'mystery-dish',
  title: 'Mystery Dish',
  category: 'Others',
  time: '10 min',
  difficulty: 'Easy',
  imageUrl: 'https://example.com/mystery.jpg',
  backgroundColor: Color(0xFFE0F2FE),
);

CartItem _item(String productName) {
  return CartItem(
    productId: 'p-$productName',
    vendorName: 'Test Stall',
    productName: productName,
    price: 100,
    unit: 'kg',
    image: 'https://example.com/$productName.jpg',
    quantity: 1,
  );
}

void main() {
  group('cartMatchesRecipes', () {
    test('empty cart returns no matches', () {
      expect(cartMatchesRecipes(const [_adobo, _sinigang], []), isEmpty);
    });

    test('recipes without ingredients are never suggested', () {
      final matches = cartMatchesRecipes(
        const [_noIngredients, _adobo],
        [_item('Chicken')],
      );
      expect(matches.map((m) => m.recipe.title), ['Adobong Manok']);
    });

    test('exact product name match counts the ingredient', () {
      final matches = cartMatchesRecipes(
        const [_adobo],
        [_item('Chicken')],
      );
      expect(matches, hasLength(1));
      expect(matches.single.matchedCount, 1);
      expect(matches.single.totalCount, 3);
      expect(matches.single.missing, ['Soy Sauce', 'Vinegar']);
      expect(matches.single.allInCart, isFalse);
    });

    test('substring match works both directions', () {
      // Ingredient "Bangus (Milkfish)" contains cart product "Bangus".
      final forward = cartMatchesRecipes(
        const [_sinigang],
        [_item('Bangus')],
      );
      expect(forward.single.matchedCount, 1);

      // Cart product "Tamarind Paste Mix" contains ingredient "Tamarind".
      final backward = cartMatchesRecipes(
        const [_sinigang],
        [_item('Tamarind Paste Mix')],
      );
      expect(backward.single.matchedCount, 1);
    });

    test('matching is case-insensitive and trims whitespace', () {
      final matches = cartMatchesRecipes(
        const [_adobo],
        [_item('  chicken '), _item('SOY SAUCE')],
      );
      expect(matches.single.matchedCount, 2);
    });

    test('every ingredient in cart marks the recipe allInCart', () {
      final matches = cartMatchesRecipes(
        const [_adobo],
        [
          _item('Chicken'),
          _item('Soy Sauce'),
          _item('Vinegar'),
          _item('Garlic'),
        ],
      );
      expect(matches.single.matchedCount, 3);
      expect(matches.single.missing, isEmpty);
      expect(matches.single.allInCart, isTrue);
    });

    test('duplicate cart items do not double-count an ingredient', () {
      final matches = cartMatchesRecipes(
        const [_adobo],
        [_item('Chicken'), _item('Chicken')],
      );
      expect(matches.single.matchedCount, 1);
    });

    test('sorting puts the most complete recipe first, ties by title', () {
      final matches = cartMatchesRecipes(
        const [_sinigang, _adobo],
        [
          _item('Chicken'),
          _item('Soy Sauce'),
          _item('Vinegar'),
          _item('Tamarind'),
        ],
      );
      expect(matches, hasLength(2));
      expect(matches.first.recipe.title, 'Adobong Manok');
      expect(matches.first.matchedCount, 3);

      final tie = cartMatchesRecipes(
        const [_adobo, _sinigang],
        [_item('Chicken')],
      );
      expect(tie.first.recipe.title, 'Adobong Manok');
    });
  });
}
