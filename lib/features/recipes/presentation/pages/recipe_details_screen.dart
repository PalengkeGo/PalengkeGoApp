import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recipe_hero_card.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recipe_ingredients_list.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recipe_stats_row.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recipe_steps_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/recipes/application/saved_recipes_provider.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/recipes/application/recipe_purchases_provider.dart';
import 'package:palengkego/core/navigation/app_routes.dart';

class RecipeDetailsScreen extends ConsumerStatefulWidget {
  final Recipe recipe;

  const RecipeDetailsScreen({super.key, required this.recipe});

  @override
  ConsumerState<RecipeDetailsScreen> createState() =>
      _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends ConsumerState<RecipeDetailsScreen> {
  final Set<String> _manuallyToggled = {};

  @override
  Widget build(BuildContext context) {
    final purchased = ref.watch(purchasedIngredientsProvider);
    final Set<String> checkedIngredients = {};

    if (widget.recipe.ingredients != null) {
      for (final ingredient in widget.recipe.ingredients!) {
        if (isIngredientPurchased(ingredient.name, purchased) ||
            _manuallyToggled.contains(ingredient.name)) {
          checkedIngredients.add(ingredient.name);
        }
      }
    }

    final recipeObject = widget.recipe;
    final savedRecipes =
        ref.watch(savedRecipesProvider).value ?? const <Recipe>[];
    final isSaved = savedRecipes.any((r) => r.id == recipeObject.id);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final hasIngredients =
        recipeObject.ingredients != null &&
        recipeObject.ingredients!.isNotEmpty;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        scaffoldMessenger.clearSnackBars();
      },
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        bottomNavigationBar: hasIngredients
            ? _AddToCartBar(
                recipe: recipeObject,
                checkedIngredients: checkedIngredients,
              )
            : null,
        body: CustomScrollView(
          slivers: [
            // App Bar with Back Button and Favorite
            SliverToBoxAdapter(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      const Text(
                        'Recipe Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          ref
                              .read(savedRecipesProvider.notifier)
                              .toggleSave(recipeObject);
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isSaved
                                    ? 'Removed "${recipeObject.title}" from Cookbook.'
                                    : 'Added "${recipeObject.title}" to Cookbook.',
                                style: const TextStyle(),
                              ),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSaved
                                ? const Color(0xFFFEE2E2)
                                : AppTheme.surfaceContainerLow,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isSaved
                                ? Icons.favorite_rounded
                                : Icons.favorite_outline_rounded,
                            size: 20,
                            color: isSaved
                                ? const Color(0xFFEF4444)
                                : AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Hero Image with Overlay
            SliverToBoxAdapter(child: RecipeHeroCard(recipe: widget.recipe)),

            // Stats Chips
            SliverToBoxAdapter(child: RecipeStatsRow(recipe: widget.recipe)),

            // Ingredients Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RecipeIngredientsList(
                  recipe: widget.recipe,
                  checkedIngredients: checkedIngredients,
                  onIngredientToggled: (name) {
                    setState(() {
                      if (_manuallyToggled.contains(name)) {
                        _manuallyToggled.remove(name);
                      } else {
                        _manuallyToggled.add(name);
                      }
                      ref
                          .read(manualPurchasedIngredientsProvider.notifier)
                          .toggleIngredient(name);
                    });
                  },
                ),
              ),
            ),

            // Procedure Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Procedure',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RecipeStepsList(recipe: widget.recipe),
                  ],
                ),
              ),
            ),

            // Bottom padding for the sticky CTA bar
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky "Add Ingredients to Cart" bottom bar
// ---------------------------------------------------------------------------
class _AddToCartBar extends ConsumerWidget {
  final Recipe recipe;
  final Set<String> checkedIngredients;
  const _AddToCartBar({required this.recipe, required this.checkedIngredients});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartNotifier = ref.read(cartItemsProvider.notifier);
    final ingredients = recipe.ingredients ?? [];

    final missingIngredients = ingredients
        .where((ing) => !checkedIngredients.contains(ing.name))
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.surfaceContainerLow)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.06),
            offset: Offset(0, -4),
            blurRadius: 12,
          ),
        ],
      ),
      child: SizedBox(
        height: 50,
        child: ElevatedButton.icon(
          onPressed: missingIngredients.isEmpty
              ? null
              : () async {
                  final allProducts = await ref.read(
                    allProductsProvider.future,
                  );
                  final allVendors = await ref.read(allVendorsProvider.future);
                  int itemsAdded = 0;
                  List<String> notFound = [];

                  for (final ingredient in missingIngredients) {
                    final ingredientName = ingredient.name.toLowerCase().trim();

                    final match = allProducts
                        .where(
                          (p) =>
                              p.name.toLowerCase().contains(ingredientName) ||
                              ingredientName.contains(p.name.toLowerCase()),
                        )
                        .firstOrNull;

                    if (match != null) {
                      final vendorName =
                          allVendors
                              .where((v) => v.id == match.vendorId)
                              .firstOrNull
                              ?.name ??
                          match.vendorId;
                      cartNotifier.addToCart(
                        CartItem(
                          productId: match.id,
                          vendorName: vendorName,
                          productName: match.name,
                          price: match.price,
                          unit: match.unit,
                          quantity: 1,
                          image: match.imageUrl,
                        ),
                      );
                      // Mark ingredient as purchased for instant recipe scratch-off
                      ref
                          .read(manualPurchasedIngredientsProvider.notifier)
                          .markAsPurchased(ingredient.name);
                      itemsAdded++;
                    } else {
                      notFound.add(ingredient.name);
                    }
                  }

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).clearSnackBars();

                  if (notFound.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              itemsAdded > 0
                                  ? 'Added $itemsAdded items, but some were missing:'
                                  : 'Missing ingredients not found in market:',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notFound.join(', '),
                              style: const TextStyle(color: Color(0xFFFCA5A5)),
                            ),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        duration: const Duration(seconds: 4),
                        action: itemsAdded > 0
                            ? SnackBarAction(
                                label: 'Dismiss',
                                textColor: Colors.white70,
                                onPressed: () => ScaffoldMessenger.of(
                                  context,
                                ).hideCurrentSnackBar(),
                              )
                            : null,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$itemsAdded ingredient${itemsAdded == 1 ? '' : 's'} added to cart!',
                          style: const TextStyle(),
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        duration: const Duration(seconds: 2),
                        action: SnackBarAction(
                          label: 'Dismiss',
                          textColor: const Color(0xFF6FCF97),
                          onPressed: () => ScaffoldMessenger.of(
                            context,
                          ).hideCurrentSnackBar(),
                        ),
                      ),
                    );
                  }

                  // Navigate to cart
                  Navigator.of(context).pushNamed(AppRoutes.cart);
                },
          icon: Icon(
            missingIngredients.isEmpty
                ? Icons.check_circle_outline
                : Icons.shopping_cart_outlined,
            size: 18,
          ),
          label: Text(
            missingIngredients.isEmpty
                ? 'All ingredients ready!'
                : 'Add ${missingIngredients.length} Ingredients to Cart',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: missingIngredients.isEmpty
                ? AppTheme.border
                : AppTheme.primaryGreen,
            foregroundColor: missingIngredients.isEmpty
                ? AppTheme.textSecondary
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            disabledBackgroundColor: AppTheme.border,
            disabledForegroundColor: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
