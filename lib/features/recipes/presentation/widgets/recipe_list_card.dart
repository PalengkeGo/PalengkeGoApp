import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/recipes/application/saved_recipes_provider.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';

/// Compact list card for a recipe, with a save-to-Cookbook heart.
class RecipeListCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeListCard({super.key, required this.recipe, required this.onTap});

  static String _fallbackImageUrl(String category, String title) {
    final cat = category.toLowerCase();
    final t = title.toLowerCase();
    if (cat.contains('dessert') || cat.contains('snack') || cat.contains('sweet')) {
      return 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=200&fit=crop';
    } else if (cat.contains('seafood') || cat.contains('fish') || t.contains('isda') || t.contains('bangus') || t.contains('tanigue')) {
      return 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=200&fit=crop';
    } else if (cat.contains('chicken') || t.contains('manok') || t.contains('adobo')) {
      return 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=200&fit=crop';
    } else if (cat.contains('pork') || cat.contains('beef') || cat.contains('meat') || t.contains('baboy') || t.contains('bicol express')) {
      return 'https://images.unsplash.com/photo-1544025162-d76694265947?w=200&fit=crop';
    } else if (cat.contains('vegetable') || cat.contains('gulay') || t.contains('talong') || t.contains('mustasa')) {
      return 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=200&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=200&fit=crop';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedRecipes =
        ref.watch(savedRecipesProvider).value ?? const <Recipe>[];
    final isSaved = savedRecipes.any((r) => r.id == recipe.id);
    final displayImage = recipe.imageUrl.isNotEmpty
        ? recipe.imageUrl
        : _fallbackImageUrl(recipe.category, recipe.title);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AdaptiveImage(
                displayImage,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: Container(
                  width: 80,
                  height: 80,
                  color: recipe.backgroundColor,
                  child: const Center(
                    child: Icon(
                      Icons.restaurant,
                      size: 24,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.category,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recipe.time,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.bar_chart_rounded,
                        size: 14,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recipe.difficulty,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isSaved
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isSaved
                    ? const Color(0xFFEF4444)
                    : AppTheme.muted,
                size: 20,
              ),
              onPressed: () {
                ref.read(savedRecipesProvider.notifier).toggleSave(recipe);
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isSaved
                          ? 'Removed "${recipe.title}" from Cookbook.'
                          : 'Added "${recipe.title}" to Cookbook.',
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
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppTheme.muted,
            ),
          ],
        ),
      ),
    );
  }
}
