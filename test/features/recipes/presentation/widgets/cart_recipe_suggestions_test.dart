import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/data/mock_cart_repository.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/recipes/application/recipe_provider.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';
import 'package:palengkego/features/recipes/presentation/pages/recipe_details_screen.dart';
import 'package:palengkego/features/recipes/presentation/widgets/cart_recipe_suggestions.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _adobo = Recipe(
  id: 'adobong-manok',
  title: 'Adobong Manok',
  category: 'Chicken',
  time: '45 min',
  difficulty: 'Easy',
  imageUrl: 'https://example.com/adobo.jpg',
  backgroundColor: Color(0xFFFEF3C7),
  ingredients: [
    RecipeIngredient(name: 'Chicken', description: '1 whole'),
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

void main() {
  late MockCartRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MockCartRepository.clearTestState();
    repository = MockCartRepository();
  });

  Future<void> seedCart(List<CartItem> items) async {
    for (final item in items) {
      await repository.addToCart(item);
    }
  }

  Widget buildSuggestions(List<Recipe> recipes) {
    return ProviderScope(
      overrides: [
        cartRepositoryProvider.overrideWithValue(repository),
        allRecipesProvider.overrideWith((ref) async => recipes),
      ],
      child: const MaterialApp(
        home: Scaffold(body: CartRecipeSuggestions()),
      ),
    );
  }

  CartItem cartItem(String productName) {
    return CartItem(
      productId: 'p-$productName',
      vendorName: 'Aling Nena',
      productName: productName,
      price: 100,
      unit: 'kg',
      image: 'https://example.com/$productName.jpg',
      quantity: 1,
    );
  }

  testWidgets('renders cards only for recipes matching the cart', (
    tester,
  ) async {
    await seedCart([cartItem('Chicken')]);
    await tester.pumpWidget(buildSuggestions(const [_adobo, _sinigang]));
    await tester.pumpAndSettle();

    expect(find.text('You can cook this!'), findsOneWidget);
    expect(find.text('Adobong Manok'), findsOneWidget);
    expect(find.text('1 of 3 ingredients'), findsOneWidget);
    expect(find.text('Sinigang na Bangus'), findsNothing);
  });

  testWidgets('shows "All ingredients!" when cart covers the whole recipe', (
    tester,
  ) async {
    await seedCart([
      cartItem('Chicken'),
      cartItem('Soy Sauce'),
      cartItem('Vinegar'),
    ]);
    await tester.pumpWidget(buildSuggestions(const [_adobo]));
    await tester.pumpAndSettle();

    expect(find.text('All ingredients!'), findsOneWidget);
  });

  testWidgets('renders nothing with an empty cart', (tester) async {
    await tester.pumpWidget(buildSuggestions(const [_adobo]));
    await tester.pumpAndSettle();

    expect(find.text('You can cook this!'), findsNothing);
    expect(find.byType(CartRecipeSuggestions), findsOneWidget);
    expect(tester.getSize(find.byType(CartRecipeSuggestions)).height, 0);
  });

  testWidgets('renders nothing when no recipe matches the cart', (
    tester,
  ) async {
    await seedCart([cartItem('Potato')]);
    await tester.pumpWidget(buildSuggestions(const [_adobo, _sinigang]));
    await tester.pumpAndSettle();

    expect(find.text('You can cook this!'), findsNothing);
  });

  testWidgets('tapping a card opens the recipe details screen', (
    tester,
  ) async {
    await seedCart([cartItem('Chicken')]);
    await tester.pumpWidget(buildSuggestions(const [_adobo]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adobong Manok'));
    await tester.pumpAndSettle();

    expect(find.byType(RecipeDetailsScreen), findsOneWidget);
    expect(find.text('Recipe Details'), findsOneWidget);
  });
}