import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';

class RecipeStatsRow extends StatelessWidget {
  final Recipe recipe;
  final int serving; // current serving count (1 = base)
  final ValueChanged<int>? onServingChanged;

  /// Optional dynamic energy string (e.g. reflecting chosen ingredient
  /// substitutes). When null, [recipe.energyLabel] is used.
  final String? energyOverride;

  const RecipeStatsRow({
    super.key,
    required this.recipe,
    this.serving = 1,
    this.onServingChanged,
    this.energyOverride,
  });

  @override
  Widget build(BuildContext context) {
    // Time adds +5 min per extra serving (Medium +10), not ×
    String scaledTime = recipe.time;
    final timeMin = int.tryParse(RegExp(r'\d+').firstMatch(recipe.time)?.group(0) ?? '');
    if (timeMin != null) {
      final extra = recipe.difficulty.toLowerCase() == 'medium' ? 10 : 5;
      scaledTime = serving == 1 ? '$timeMin min' : '${timeMin + (serving - 1) * extra} min';
    }

    String scaledEnergy = energyOverride ?? recipe.energyLabel();
    final cal = int.tryParse(RegExp(r'\d+').firstMatch(scaledEnergy)?.group(0) ?? '');
    if (cal != null && serving != 1) {
      scaledEnergy = scaledEnergy.replaceFirst(RegExp(r'\d+'), (cal * serving).toString());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatChip(
            icon: Icons.timer_outlined,
            label: 'TIME',
            value: scaledTime,
          ),
          const SizedBox(width: 12),
          _buildServingChip(context),
          const SizedBox(width: 12),
          _buildStatChip(
            icon: Icons.local_fire_department_outlined,
            label: 'ENERGY',
            value: scaledEnergy,
          ),
        ],
      ),
    );
  }

  Widget _buildServingChip(BuildContext context) {
    if (onServingChanged == null) {
      return _buildStatChip(
        icon: Icons.people_outline_rounded,
        label: 'SERVING',
        value: recipe.serving ?? (serving == 1 ? '4 Persons' : '$serving Persons'),
      );
    }
    final label = serving == 1 ? '1 Person' : '$serving Persons';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.people_outline_rounded, size: 20, color: AppTheme.primaryGreen),
            const SizedBox(height: 4),
            const Text('SERVING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.muted, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _counterBtn(Icons.remove, () => onServingChanged!(serving > 1 ? serving - 1 : 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ),
                  _counterBtn(Icons.add, () => onServingChanged!(serving + 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryGreen),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
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
