import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:palengkego/features/recipes/application/recipe_unlock.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';

void main() {
  group('recipe_unlock', () {
    const mangoFloat = Recipe(
      id: '131',
      title: 'Mango Float',
      category: 'Dessert',
      time: '20 min',
      difficulty: 'Easy',
      imageUrl: 'https://example.com/mango_float.jpg',
      backgroundColor: Color(0xFFFEF3C7),
      ingredients: [
        RecipeIngredient(
          name: '1.5 ripe mangoes, sliced',
          description: '1.5 ripe mangoes, sliced',
        ),
        RecipeIngredient(
          name: '1 pack graham crackers',
          description: '1 pack graham crackers',
        ),
      ],
    );

    const chickenAdobo = Recipe(
      id: '1',
      title: 'Chicken Adobo',
      category: 'Main Dish',
      time: '35 min',
      difficulty: 'Easy',
      imageUrl: 'https://example.com/adobo.jpg',
      backgroundColor: Color(0xFFFEF3C7),
      ingredients: [
        RecipeIngredient(
          name: '500g chicken cuts',
          description: '500g chicken cuts',
        ),
      ],
    );

    test('unlocks recipes matching purchased "Sweet Mangoes" by title or ingredients', () {
      final purchased = {'Sweet Mangoes'};
      final unlocked = unlockedRecipes([mangoFloat, chickenAdobo], purchased);

      expect(unlocked.length, 1);
      expect(unlocked.first.title, 'Mango Float');
    });

    test('extracts purchased product names from orders correctly', () {
      final orders = <MarketOrder>[
        MarketOrder(
          id: '#202609241',
          customerUid: 'customer-001',
          stallId: 'stall-001',
          vendorName: 'Diosa Fruit Stand',
          vendorImage: '',
          customerName: 'Customer',
          status: OrderStatus.pending,
          paymentStatus: PaymentStatus.pending,
          fulfillmentMethod: FulfillmentMethod.pickup,
          deliveryFee: 0,
          serviceFee: 0,
          placedAt: DateTime.now(),
          items: const [
            OrderLineItem(
              productId: 'p1',
              productName: 'Sweet Mangoes',
              quantity: 1,
              unitPrice: 38,
              unit: '1/4 kg',
              image: '',
            ),
          ],
        ),
      ];

      final purchasedNames = purchasedProductNamesFrom(orders);
      expect(purchasedNames, contains('sweet mangoes'));

      final unlocked = unlockedRecipes([mangoFloat, chickenAdobo], purchasedNames);
      expect(unlocked.length, 1);
      expect(unlocked.first.id, '131');
    });

    test('excludes false-positive compound derivatives like banana ketchup and banana heart', () {
      const bananaOats = Recipe(
        id: 'b1',
        title: 'Banana Oats Bites',
        category: 'Snack',
        time: '15 min',
        difficulty: 'Easy',
        imageUrl: '',
        backgroundColor: Color(0xFFFEF3C7),
        ingredients: [
          RecipeIngredient(name: '2 ripe bananas', description: 'mashed'),
        ],
      );

      const spaghetti = Recipe(
        id: 's1',
        title: 'Filipino Spaghetti',
        category: 'Main Dish',
        time: '30 min',
        difficulty: 'Easy',
        imageUrl: '',
        backgroundColor: Color(0xFFFEF3C7),
        ingredients: [
          RecipeIngredient(name: '1 cup banana ketchup', description: 'sweet style'),
        ],
      );

      const kareKare = Recipe(
        id: 'k1',
        title: 'Kare-Kare',
        category: 'Main Dish',
        time: '60 min',
        difficulty: 'Medium',
        imageUrl: '',
        backgroundColor: Color(0xFFFEF3C7),
        ingredients: [
          RecipeIngredient(name: '1 piece banana heart', description: 'sliced'),
        ],
      );

      const suman = Recipe(
        id: 'su1',
        title: 'Suman sa Cassava',
        category: 'Snack',
        time: '45 min',
        difficulty: 'Medium',
        imageUrl: '',
        backgroundColor: Color(0xFFFEF3C7),
        ingredients: [
          RecipeIngredient(name: 'banana leaves', description: 'wilted for wrapping'),
        ],
      );

      final purchased = {'Banana'};
      final unlocked = unlockedRecipes(
        [bananaOats, spaghetti, kareKare, suman],
        purchased,
      );

      expect(unlocked.length, 1);
      expect(unlocked.first.title, 'Banana Oats Bites');
    });

    test('limits the number of recommended recipes per ingredient', () {
      final recipes = List<Recipe>.generate(
        10,
        (i) => Recipe(
          id: 'b_$i',
          title: 'Banana Recipe $i',
          category: 'Snack',
          time: '10 min',
          difficulty: 'Easy',
          imageUrl: '',
          backgroundColor: const Color(0xFFFEF3C7),
          ingredients: [
            const RecipeIngredient(name: '1 banana', description: 'sliced'),
          ],
        ),
      );

      final purchased = {'Banana'};
      final unlocked = unlockedRecipes(recipes, purchased, maxPerIngredient: 3);

      expect(unlocked.length, 3);
    });
  });
}

