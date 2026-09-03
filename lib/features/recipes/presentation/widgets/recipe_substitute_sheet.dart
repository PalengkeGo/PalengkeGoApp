import 'package:flutter/material.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';

/// Bottom sheet shown when the user TICKS an ingredient that offers
/// substitutes. It asks whether to keep the original or switch to one of the
/// listed [RecipeSubstitute]s. Returns the chosen [RecipeSubstitute], or
/// `null` to keep the original ingredient.
Future<RecipeSubstitute?> showRecipeSubstituteSheet(
  BuildContext context, {
  required RecipeIngredient ingredient,
}) {
  final subs = ingredient.substitutes ?? const <RecipeSubstitute>[];
  return showModalBottomSheet<RecipeSubstitute>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _SubstituteSheet(
      ingredient: ingredient,
      substitutes: subs,
    ),
  );
}

class _SubstituteSheet extends StatelessWidget {
  const _SubstituteSheet({required this.ingredient, required this.substitutes});

  final RecipeIngredient ingredient;
  final List<RecipeSubstitute> substitutes;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: mq.viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'A substitute is available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'For “${ingredient.name}” (${ingredient.description}). '
                'Swap it for one of these market-friendly options instead?',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              // Options
              ...substitutes.map((s) => _Option(
                    substitute: s,
                    onTap: () => Navigator.pop(context, s),
                  )),
              const SizedBox(height: 12),
              // Keep original
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, null),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.surfaceContainer),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Keep ${ingredient.name}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.substitute, required this.onTap});

  final RecipeSubstitute substitute;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.scaffoldBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      substitute.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      substitute.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (substitute.calorie != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${substitute.calorie} kcal',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}