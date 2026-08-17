import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/navigation/app_router.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/login_screen.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/data/mock_cart_repository.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/cart/presentation/pages/shopping_cart_screen.dart';
import 'package:palengkego/features/recipes/application/recipe_provider.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';
import 'package:palengkego/features/recipes/presentation/pages/recipe_details_screen.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  late MockCartRepository repository;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    MockCartRepository.clearTestState();
    repository = MockCartRepository()
      ..addToCart(
        const CartItem(
          productId: 'm1',
          vendorName: 'Diosa Fruit Stand',
          productName: 'Sweet Mangoes',
          price: 150,
          unit: 'kg',
          image: 'https://example.com/mango.jpg',
        ),
      );
  });

  Widget buildCartApp({required AppUser? user}) {
    return ProviderScope(
      overrides: [
        cartRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith(() => _TestAuthNotifier(user)),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: ShoppingCartScreen(),
      ),
    );
  }

  group('ShoppingCartScreen auth checkout flow', () {
    testWidgets('guest can view cart items before logging in', (tester) async {
      usePhoneViewport(tester);

      await tester.pumpWidget(buildCartApp(user: null));
      await tester.pumpAndSettle();

      expect(find.text('Shopping Cart'), findsOneWidget);
      expect(find.text('Sweet Mangoes'), findsOneWidget);
      expect(find.text('Login Required'), findsNothing);
      expect(repository.items, hasLength(1));
    });

    testWidgets('guest checkout prompts login and keeps cart contents', (
      tester,
    ) async {
      usePhoneViewport(tester);

      await tester.pumpWidget(buildCartApp(user: null));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();

      expect(find.text('Proceed to Checkout'), findsOneWidget);

      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();

      expect(find.text('Login Required'), findsOneWidget);
      expect(
        find.text('You must be logged in to checkout your items.'),
        findsOneWidget,
      );
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
      expect(repository.items, hasLength(1));
      expect(repository.items.single.productName, 'Sweet Mangoes');
    });

    testWidgets('guest can back out of login without losing cart contents', (
      tester,
    ) async {
      usePhoneViewport(tester);

      await tester.pumpWidget(buildCartApp(user: null));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back!'), findsOneWidget);

      Navigator.of(tester.element(find.byType(LoginScreen))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Shopping Cart'), findsOneWidget);
      expect(find.text('Sweet Mangoes'), findsOneWidget);
      expect(find.text('Login Required'), findsNothing);
      expect(repository.items, hasLength(1));
      expect(repository.items.single.productName, 'Sweet Mangoes');
    });

    testWidgets('authenticated checkout skips login prompt', (tester) async {
      usePhoneViewport(tester);

      await tester.pumpWidget(buildCartApp(user: MockUsers.customer));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();

      expect(find.text('Proceed to Checkout'), findsOneWidget);

      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();

      expect(find.text('Login Required'), findsNothing);
      expect(find.text('Checkout'), findsWidgets);
    });
  });

  group('ShoppingCartScreen cook-with-your-cart strip', () {
    const bangusRecipe = Recipe(
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

    void seedMatchingCart() {
      MockCartRepository.clearTestState();
      repository = MockCartRepository()
        ..addToCart(
          const CartItem(
            productId: 'm2',
            vendorName: 'Aling Nena',
            productName: 'Bangus',
            price: 180,
            unit: 'kg',
            image: 'https://example.com/bangus.jpg',
          ),
        );
    }

    Widget buildCartWithRecipes() {
      return ProviderScope(
        overrides: [
          cartRepositoryProvider.overrideWithValue(repository),
          authProvider.overrideWith(() => _TestAuthNotifier(MockUsers.customer)),
          sharedPreferencesProvider.overrideWithValue(prefs),
          allRecipesProvider.overrideWith((ref) async => [bangusRecipe]),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: ShoppingCartScreen(),
        ),
      );
    }

    setUp(() {
      seedMatchingCart();
    });

    testWidgets('shows a dish card when a cart item matches a recipe', (
      tester,
    ) async {
      usePhoneViewport(tester);

      await tester.pumpWidget(buildCartWithRecipes());
      await tester.pumpAndSettle();

      expect(find.text('You can cook this!'), findsOneWidget);
      expect(find.text('Sinigang na Bangus'), findsOneWidget);
      expect(find.text('1 of 3 ingredients'), findsOneWidget);
    });

    testWidgets('tapping the dish card opens the recipe details screen', (
      tester,
    ) async {
      usePhoneViewport(tester);

      await tester.pumpWidget(buildCartWithRecipes());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sinigang na Bangus'));
      await tester.pumpAndSettle();

      expect(find.byType(RecipeDetailsScreen), findsOneWidget);
      expect(find.text('Recipe Details'), findsOneWidget);
    });
  });
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.initialUser);

  final AppUser? initialUser;

  @override
  AppUser? build() => initialUser;
}
