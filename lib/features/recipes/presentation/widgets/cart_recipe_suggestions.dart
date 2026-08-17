import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/recipes/application/recipe_cart_matcher.dart';
import 'package:palengkego/features/recipes/application/recipe_provider.dart';
import 'package:palengkego/features/recipes/presentation/pages/recipe_details_screen.dart';

/// Horizontal strip of dish cards for recipes the cart can already cook.
///
/// Renders nothing when the cart is empty or no recipe matches, so it can be
/// dropped into the cart screen unconditionally.
class CartRecipeSuggestions extends ConsumerWidget {
  const CartRecipeSuggestions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(allRecipesProvider).value ?? const [];
    final cartItems = ref.watch(cartItemsProvider).value ?? const [];

    final matches = cartMatchesRecipes(recipes, cartItems);
    if (matches.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.restaurant_menu_rounded,
                  size: 18,
                  color: AppTheme.primaryGreen,
                ),
                SizedBox(width: 6),
                Text(
                  'You can cook this!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Text(
              'Based on what\'s in your cart',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: matches.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _RecipeSuggestionCard(match: matches[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeSuggestionCard extends StatelessWidget {
  const _RecipeSuggestionCard({required this.match});

  final RecipeCartMatch match;

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;

    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(PageTransitions.slideFromRight(RecipeDetailsScreen(recipe: recipe)));
      },
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AdaptiveImage(
                        recipe.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: AppTheme.surfaceContainerLow,
                          child: const Icon(
                            Icons.restaurant,
                            color: AppTheme.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: match.allInCart
                            ? const Color(0xFF047857)
                            : AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        match.allInCart
                            ? 'All ingredients!'
                            : '${match.matchedCount} of ${match.totalCount} ingredients',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recipe.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}