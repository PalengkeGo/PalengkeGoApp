import 'package:flutter/material.dart';
import 'package:palengkego/features/recipes/data/recipe_repository.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';

class MockRecipeRepository implements RecipeRepository {
  static const _recipes = <Recipe>[
    Recipe(
      id: 'sinigang-na-hipon',
      title: 'Sinigang na Hipon',
      category: 'Seafood',
      time: '30 min',
      difficulty: 'Easy',
      imageUrl:
          'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=400&h=250&fit=crop',
      backgroundColor: Color(0xFFE0F2FE),
      serving: '3-4 servings',
      calories: '280 kcal',
      ingredients: [
        RecipeIngredient(
          name: 'Shrimp',
          description: '500g fresh head-on shrimp',
        ),
        RecipeIngredient(
          name: 'Tamarind',
          description: '1 pack sinigang mix or fresh tamarind pulp',
        ),
        RecipeIngredient(name: 'Tomato', description: '2 large, quartered'),
        RecipeIngredient(name: 'Onion', description: '1 medium, sliced'),
        RecipeIngredient(name: 'Radish', description: '1 medium, sliced'),
        RecipeIngredient(name: 'Chili', description: '2 pieces siling haba'),
        RecipeIngredient(
          name: 'Kangkong',
          description: '1 bunch water spinach',
        ),
      ],
      steps: [
        RecipeStep(
          title: 'Boil Aromatics',
          description:
              'In a pot, bring water to a boil with tomatoes and onions until soft.',
        ),
        RecipeStep(
          title: 'Add Vegetables & Sourness',
          description:
              'Add sliced radish and tamarind mix. Simmer for 5 minutes.',
        ),
        RecipeStep(
          title: 'Cook Shrimp',
          description:
              'Gently add the shrimp and long green chilis. Cook for 3-4 minutes until shrimp turns pink.',
        ),
        RecipeStep(
          title: 'Finish with Greens',
          description:
              'Toss in the kangkong leaves, turn off heat, cover and let wilt for 2 minutes before serving.',
        ),
      ],
    ),
    Recipe(
      id: 'chicken-adobo',
      title: 'Chicken Adobo',
      category: 'Chicken',
      time: '45 min',
      difficulty: 'Medium',
      imageUrl:
          'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=400&h=250&fit=crop',
      backgroundColor: Color(0xFFFEE2E2),
      serving: '4 servings',
      calories: '420 kcal',
      ingredients: [
        RecipeIngredient(
          name: 'Chicken',
          description: '1 kg chicken cut into pieces',
        ),
        RecipeIngredient(
          name: 'Soy Sauce',
          description: '1/2 cup dark soy sauce',
        ),
        RecipeIngredient(name: 'Vinegar', description: '1/3 cup white vinegar'),
        RecipeIngredient(name: 'Garlic', description: '1 head garlic, crushed'),
        RecipeIngredient(name: 'Onion', description: '1 medium, sliced'),
        RecipeIngredient(
          name: 'Black Pepper',
          description: '1 tbsp whole peppercorns',
        ),
        RecipeIngredient(name: 'Bay Leaves', description: '3 dried bay leaves'),
      ],
      steps: [
        RecipeStep(
          title: 'Marinate Chicken',
          description:
              'Combine chicken, garlic, soy sauce, and black pepper in a bowl. Marinate for at least 30 minutes.',
        ),
        RecipeStep(
          title: 'Sear Chicken',
          description:
              'Heat oil in a pan. Pan-fry marinated chicken pieces for 2-3 minutes per side until lightly browned.',
        ),
        RecipeStep(
          title: 'Simmer',
          description:
              'Pour in the marinade, water, peppercorns, and bay leaves. Bring to a boil, then reduce heat and simmer for 20 minutes.',
        ),
        RecipeStep(
          title: 'Add Vinegar',
          description:
              'Pour in vinegar. Let it boil uncovered without stirring for 5 minutes. Simmer until sauce reduces and chicken is tender.',
        ),
      ],
    ),
    Recipe(
      id: 'ginisang-ampalaya',
      title: 'Ginisang Ampalaya',
      category: 'Vegetables',
      time: '20 min',
      difficulty: 'Easy',
      imageUrl:
          'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&h=250&fit=crop',
      backgroundColor: Color(0xFFDCFCE7),
      serving: '2-3 servings',
      calories: '150 kcal',
      ingredients: [
        RecipeIngredient(
          name: 'Ampalaya',
          description: '2 medium bitter melons, sliced thinly',
        ),
        RecipeIngredient(name: 'Egg', description: '2 large eggs, beaten'),
        RecipeIngredient(name: 'Tomato', description: '2 medium, chopped'),
        RecipeIngredient(name: 'Onion', description: '1 small, chopped'),
        RecipeIngredient(name: 'Garlic', description: '3 cloves, minced'),
      ],
      steps: [
        RecipeStep(
          title: 'Prep Bitter Melon',
          description:
              'Rub sliced ampalaya with salt and soak in water for 10 minutes to reduce bitterness. Rinse thoroughly and squeeze dry.',
        ),
        RecipeStep(
          title: 'Sauté Aromatics',
          description:
              'Sauté garlic, onion, and tomatoes in a pan until tomatoes are soft.',
        ),
        RecipeStep(
          title: 'Cook Ampalaya',
          description:
              'Add the ampalaya and stir-fry for 4-5 minutes until tender but still crisp.',
        ),
        RecipeStep(
          title: 'Add Egg',
          description:
              'Pour in the beaten eggs. Let set slightly, then scramble and toss everything together. Season with salt and pepper.',
        ),
      ],
    ),
    Recipe(
      id: 'pork-sinigang',
      title: 'Pork Sinigang',
      category: 'Pork',
      time: '60 min',
      difficulty: 'Medium',
      imageUrl:
          'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=400&h=250&fit=crop',
      backgroundColor: Color(0xFFFEF3C7),
      serving: '4-5 servings',
      calories: '450 kcal',
      ingredients: [
        RecipeIngredient(
          name: 'Pork',
          description: '1 kg pork belly or ribs, cut into cubes',
        ),
        RecipeIngredient(name: 'Tamarind', description: '1 pack sinigang mix'),
        RecipeIngredient(name: 'Tomato', description: '2 large, quartered'),
        RecipeIngredient(name: 'Onion', description: '1 medium, sliced'),
        RecipeIngredient(name: 'Radish', description: '1 medium, sliced'),
        RecipeIngredient(name: 'Chili', description: '2 pieces siling haba'),
        RecipeIngredient(
          name: 'Kangkong',
          description: '1 bunch water spinach',
        ),
        RecipeIngredient(name: 'Eggplant', description: '1 medium, sliced'),
      ],
      steps: [
        RecipeStep(
          title: 'Tenderize Pork',
          description:
              'Boil pork belly in a pot with onions and tomatoes for 35-40 minutes until meat is tender.',
        ),
        RecipeStep(
          title: 'Add Vegetables',
          description:
              'Add radish, eggplant, and long chilis. Stir in the sinigang tamarind mix. Simmer for 5-8 minutes.',
        ),
        RecipeStep(
          title: 'Finish with Greens',
          description:
              'Add kangkong leaves, turn off heat, cover and let steam for 2 minutes before serving.',
        ),
      ],
    ),
    Recipe(
      id: 'mango-sticky-rice',
      title: 'Mango Sticky Rice',
      category: 'Dessert',
      time: '25 min',
      difficulty: 'Easy',
      imageUrl:
          'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=400&h=250&fit=crop',
      backgroundColor: Color(0xFFFEF3C7),
      serving: '2-3 servings',
      calories: '350 kcal',
      ingredients: [
        RecipeIngredient(
          name: 'Mango',
          description: '2 large sweet ripe yellow mangoes, sliced',
        ),
        RecipeIngredient(
          name: 'Glutinous Rice',
          description: '1 cup glutinous sweet rice',
        ),
        RecipeIngredient(
          name: 'Coconut Milk',
          description: '1 cup canned coconut milk',
        ),
        RecipeIngredient(name: 'Sugar', description: '1/2 cup white sugar'),
        RecipeIngredient(name: 'Salt', description: '1/2 tsp salt'),
      ],
      steps: [
        RecipeStep(
          title: 'Cook Rice',
          description:
              'Soak glutinous rice for 1 hour. Steam the rice for about 20 minutes until tender.',
        ),
        RecipeStep(
          title: 'Make Sweet Sauce',
          description:
              'In a saucepan, simmer coconut milk, sugar, and salt over low heat until sugar dissolves. Do not boil.',
        ),
        RecipeStep(
          title: 'Mix Rice and Sauce',
          description:
              'Pour 3/4 of the warm coconut sauce over the cooked rice. Cover and let sit for 15 minutes to absorb.',
        ),
        RecipeStep(
          title: 'Serve',
          description:
              'Plate the sweet sticky rice alongside fresh mango slices. Drizzle the remaining coconut sauce on top.',
        ),
      ],
    ),
    Recipe(
      id: 'mango-graham-shake',
      title: 'Mango Graham Shake',
      category: 'Dessert',
      time: '10 min',
      difficulty: 'Easy',
      imageUrl:
          'https://images.unsplash.com/photo-1553530979-7ee52a2670c2?w=400&h=250&fit=crop',
      backgroundColor: Color(0xFFFEF3C7),
      serving: '2 servings',
      calories: '290 kcal',
      ingredients: [
        RecipeIngredient(
          name: 'Mango',
          description: '2 large sweet yellow mangoes',
        ),
        RecipeIngredient(
          name: 'Graham',
          description: '1/2 cup crushed graham crackers',
        ),
        RecipeIngredient(
          name: 'Condensed Milk',
          description: '3 tbsp sweet condensed milk',
        ),
        RecipeIngredient(name: 'Milk', description: '1 cup fresh whole milk'),
        RecipeIngredient(name: 'Ice', description: '2 cups crushed ice'),
      ],
      steps: [
        RecipeStep(
          title: 'Blend Shake',
          description:
              'In a blender, combine mango flesh, condensed milk, whole milk, and crushed ice. Blend until smooth.',
        ),
        RecipeStep(
          title: 'Layer Ingredients',
          description:
              'In a serving glass, add a layer of crushed graham crackers at the bottom.',
        ),
        RecipeStep(
          title: 'Pour and Garnish',
          description:
              'Pour in the blended mango shake. Garnish with more crushed grahams and fresh mango cubes on top.',
        ),
      ],
    ),
    Recipe(
      id: 'turon',
      title: 'Turon (Banana Spring Rolls)',
      category: 'Dessert',
      time: '20 min',
      difficulty: 'Easy',
      imageUrl:
          'https://images.unsplash.com/photo-1601050690597-df05688dc660?w=400&h=250&fit=crop',
      backgroundColor: Color(0xFFFEF3C7),
      serving: '3-4 servings',
      calories: '320 kcal',
      ingredients: [
        RecipeIngredient(
          name: 'Bananas',
          description: '6 pieces saba bananas, halved lengthwise',
        ),
        RecipeIngredient(
          name: 'Spring Roll Wrappers',
          description: '12 pieces lumpia wrapper',
        ),
        RecipeIngredient(name: 'Brown Sugar', description: '1 cup brown sugar'),
        RecipeIngredient(
          name: 'Jackfruit',
          description: '1/2 cup langka (jackfruit) strips (optional)',
        ),
        RecipeIngredient(
          name: 'Cooking Oil',
          description: '2 cups oil for frying',
        ),
      ],
      steps: [
        RecipeStep(
          title: 'Coat Bananas',
          description:
              'Roll the banana halves in brown sugar until fully coated.',
        ),
        RecipeStep(
          title: 'Wrap',
          description:
              'Place a coated banana and some jackfruit strips on a wrapper. Fold and roll tightly. Seal the edges with a bit of water.',
        ),
        RecipeStep(
          title: 'Fry',
          description:
              'Heat oil in a pan. Fry the wrapped bananas until golden brown and crispy. Sprinkle some extra brown sugar in the oil to caramelize and stick to the wrapper.',
        ),
        RecipeStep(
          title: 'Drain and Serve',
          description:
              'Remove from oil and let drain on a wire rack. Serve warm.',
        ),
      ],
    ),
  ];

  @override
  Future<List<Recipe>> getRecipes() async {
    return List<Recipe>.unmodifiable(_recipes);
  }

  @override
  Future<Recipe> getFeaturedRecipe() async {
    return _recipes.first;
  }

  @override
  Future<List<Recipe>> getMoreRecipes() async {
    return List<Recipe>.unmodifiable(_recipes.skip(1));
  }
}
