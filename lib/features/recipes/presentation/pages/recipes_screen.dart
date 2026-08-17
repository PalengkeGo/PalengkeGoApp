import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/core/widgets/empty_state.dart';
import 'package:palengkego/features/recipes/application/recipe_provider.dart';
import 'package:palengkego/features/recipes/application/recipe_unlock.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recipes_header.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recipe_category_chips.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recipe_featured_card.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recipe_list_card.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'recipe_details_screen.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final allRecipes = ref.watch(allRecipesProvider).value ?? const <Recipe>[];
    final ordersAsync = ref.watch(orderServiceProvider);

    final purchasedProductNames = <String>{};
    ordersAsync.whenData((orders) {
      purchasedProductNames.addAll(purchasedProductNamesFrom(orders));
    });

    final unlocked = unlockedRecipes(allRecipes, purchasedProductNames);

    final categories = ['All', ...unlocked.map((r) => r.category).toSet()];

    final filteredRecipes = _selectedCategory == 'All'
        ? unlocked
        : unlocked.where((r) => r.category == _selectedCategory).toList();

    final featuredRecipe = filteredRecipes.isNotEmpty
        ? filteredRecipes.first
        : null;
    final moreRecipes = filteredRecipes.length > 1
        ? filteredRecipes.skip(1).toList()
        : <Recipe>[];

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            const RecipesHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Cook with fresh ingredients\nfrom your local market',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (unlocked.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 48,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF0FDF4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                size: 48,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Locked Recipes',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Purchase fresh ingredients like Mango, Chicken, Pork, or Vegetables from Diosa Fruit Stand or other stalls to unlock delicious local recipes!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      RecipeCategoryChips(
                        categories: categories,
                        selectedCategory: _selectedCategory,
                        onSelect: (cat) =>
                            setState(() => _selectedCategory = cat),
                      ),
                      const SizedBox(height: 24),
                      if (featuredRecipe != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Featured Recipe',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: RecipeFeaturedCard(
                            recipe: featuredRecipe,
                            onTap: () => _openRecipe(context, featuredRecipe),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (moreRecipes.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'More Recipes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: moreRecipes.length,
                          itemBuilder: (cellContext, index) {
                            final recipe = moreRecipes[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: RecipeListCard(
                                recipe: recipe,
                                onTap: () => _openRecipe(context, recipe),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (filteredRecipes.isEmpty)
                        const EmptyState(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 40,
                          ),
                          title: 'No recipes found in this category.',
                          titleStyle: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRecipe(BuildContext context, Recipe recipe) {
    Navigator.of(
      context,
    ).push(PageTransitions.slideFromRight(RecipeDetailsScreen(recipe: recipe)));
  }
}
