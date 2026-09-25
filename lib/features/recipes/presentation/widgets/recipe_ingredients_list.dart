import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';

class RecipeIngredientsList extends StatelessWidget {
  final Recipe recipe;
  final Set<String> checkedIngredients;
  final ValueChanged<String> onIngredientToggled;
  final int serving; // 1 = base, scales quantity display

  /// Original ingredient name → substitute the user chose. Shown as a small
  /// "Using X instead" indicator under checked ingredients.
  final Map<String, RecipeSubstitute> substitutesUsed;

  const RecipeIngredientsList({
    super.key,
    required this.recipe,
    required this.checkedIngredients,
    required this.substitutesUsed,
    required this.onIngredientToggled,
    this.serving = 1,
  });

  String _formatQuantity(double value) {
    if (value <= 0) return '0';
    final whole = value.floor();
    final rem = value - whole;

    String frac = '';
    if ((rem - 0.5).abs() < 0.04) {
      frac = '½';
    } else if ((rem - 0.25).abs() < 0.04) {
      frac = '¼';
    } else if ((rem - 0.75).abs() < 0.04) {
      frac = '¾';
    } else if ((rem - 0.333).abs() < 0.04 || (rem - 0.33).abs() < 0.04) {
      frac = '⅓';
    } else if ((rem - 0.667).abs() < 0.04 || (rem - 0.66).abs() < 0.04) {
      frac = '⅔';
    } else if ((rem - 0.125).abs() < 0.04) {
      frac = '⅛';
    } else if ((rem - 0.375).abs() < 0.04) {
      frac = '⅜';
    } else if ((rem - 0.625).abs() < 0.04) {
      frac = '⅝';
    } else if ((rem - 0.875).abs() < 0.04) {
      frac = '⅞';
    } else if (rem < 0.04) {
      frac = '';
    } else {
      return value.toStringAsFixed(1).replaceAll(RegExp(r'\.?0+$'), '');
    }

    if (whole == 0) {
      return frac.isNotEmpty ? frac : '0';
    } else {
      return frac.isNotEmpty ? '$whole $frac' : '$whole';
    }
  }

  /// Scales a leading quantity like "1/2 cups ..." or "1.5 ube ..." by [serving].
  String _scaledName(String raw) {
    final m = RegExp(
      r'^\s*([0-9]+(?:\.[0-9]+)?|[0-9]+/[0-9]+|[½¼¾⅛⅜⅝⅞⅓⅔])\s*',
    ).firstMatch(raw);
    if (m == null) return raw;
    final qtyStr = m.group(1)!;
    double qty;
    if (qtyStr.contains('/')) {
      final parts = qtyStr.split('/');
      qty = double.parse(parts[0]) / double.parse(parts[1]);
    } else if (qtyStr == '½') {
      qty = 0.5;
    } else if (qtyStr == '¼') {
      qty = 0.25;
    } else if (qtyStr == '¾') {
      qty = 0.75;
    } else if (qtyStr == '⅛') {
      qty = 0.125;
    } else if (qtyStr == '⅓') {
      qty = 1 / 3;
    } else if (qtyStr == '⅔') {
      qty = 2 / 3;
    } else {
      qty = double.tryParse(qtyStr) ?? 1;
    }
    final scaled = qty * serving;
    final scaledStr = _formatQuantity(scaled);
    return raw.replaceFirst(
      RegExp(r'^\s*([0-9]+(?:\.[0-9]+)?|[0-9]+/[0-9]+|[½¼¾⅛⅜⅝⅞⅓⅔])\s*'),
      '$scaledStr ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = recipe.ingredients ?? _defaultIngredients;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Ingredients',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${ingredients.length} Items',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ingredients.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final ingredient = ingredients[index];
            final name = ingredient.name;
            final description = ingredient.description;
            final imageUrl = ingredient.imageUrl;
            final isChecked = checkedIngredients.contains(name);
            final usedSubstitute = substitutesUsed[name];

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isChecked ? AppTheme.primaryGreen : AppTheme.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Checkbox tap area (toggles manual checked state)
                    GestureDetector(
                      onTap: () => onIngredientToggled(name),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isChecked
                              ? AppTheme.primaryGreen
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isChecked
                                ? AppTheme.primaryGreen
                                : const Color(0xFFCBD5E1),
                            width: 2,
                          ),
                        ),
                        child: isChecked
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Ingredient info area - Tapping takes user to Recommended Stores Screen (Image 2 flow)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.recommendedIngredientStores,
                            arguments: RecommendedIngredientStoresRouteArgs(
                              ingredientName: name,
                              recipeTitle: recipe.title,
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _scaledName(name),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isChecked
                                                ? AppTheme.primaryGreen
                                                : AppTheme.textPrimary,
                                            decoration: isChecked
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                      ),
                                      if (!isChecked) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFA7F3D0),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Find Store',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF047857),
                                                ),
                                              ),
                                              SizedBox(width: 2),
                                              Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                size: 9,
                                                color: Color(0xFF047857),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (description.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      description,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                  ],
                                  if (usedSubstitute != null) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.swap_horiz_rounded,
                                            size: 11,
                                            color: Color(0xFF047857),
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Using ${usedSubstitute.name} instead',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF047857),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Optional Image
                            if (imageUrl != null) ...[
                              const SizedBox(width: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                              child: AdaptiveImage(
                                imageUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  width: 44,
                                  height: 44,
                                  color: AppTheme.surfaceContainerLow,
                                  child: const Icon(
                                    Icons.image,
                                    size: 18,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
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
          },
        ),
      ],
    );
  }

  // Default data for demo
  static final List<RecipeIngredient> _defaultIngredients = [
    const RecipeIngredient(
      name: 'Bangus (Milkfish)',
      description: '1 large, sliced into 3-4 pieces',
    ),
    const RecipeIngredient(
      name: 'Kangkong (Water Spinach)',
      description: '2 bunches, trimmed and washed',
    ),
    const RecipeIngredient(
      name: 'Tamarind',
      description: 'Fresh/powder: 1/2 cup mix',
    ),
    const RecipeIngredient(name: 'Tomato', description: 'One piece, quartered'),
    const RecipeIngredient(name: 'Onion', description: '1 medium, sliced'),
    const RecipeIngredient(
      name: 'Radish',
      description: '1 small, sliced thinly',
    ),
    const RecipeIngredient(
      name: 'Chili (Siling Habà)',
      description: '2-3 pieces for heat',
    ),
  ];
}
