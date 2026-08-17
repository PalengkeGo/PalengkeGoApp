import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';

class RecipeStepsList extends StatelessWidget {
  final Recipe recipe;

  const RecipeStepsList({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final steps = recipe.steps ?? _defaultSteps;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: steps.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final step = steps[index];
        final number = index + 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (number < steps.length)
                  Container(width: 2, height: 60, color: AppTheme.border),
              ],
            ),
            const SizedBox(width: 16),
            // Step card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.description,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Default data for demo
  static final List<RecipeStep> _defaultSteps = [
    const RecipeStep(
      title: 'Boil the Broth Base',
      description:
          'In a large pot, bring 1 liter of water to a boil. Add the tamarind/powder mix, tomato, onion to extract juices. Simmer for 10 minutes until softened.',
    ),
    const RecipeStep(
      title: 'Add Fish and Hard Veggies',
      description:
          'Gently drop in the Bangus slices and add the radish. Cover and simmer for 5-8 minutes. Be careful not to overcook the fish to maintain its flaky texture.',
    ),
    const RecipeStep(
      title: 'Season and Finish',
      description:
          'Drop in the kangkong and green chilies. Season with fish sauce, patis or salt to taste. Turn off heat once cooked. Serve with steamed rice.',
    ),
  ];
}
