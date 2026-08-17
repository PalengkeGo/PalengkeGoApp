import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';

class RecipeStatsRow extends StatelessWidget {
  final Recipe recipe;

  const RecipeStatsRow({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatChip(
            icon: Icons.timer_outlined,
            label: 'TIME',
            value: recipe.time,
          ),
          const SizedBox(width: 12),
          _buildStatChip(
            icon: Icons.people_outline_rounded,
            label: 'SERVING',
            value: recipe.serving ?? '4 Persons',
          ),
          const SizedBox(width: 12),
          _buildStatChip(
            icon: Icons.local_fire_department_outlined,
            label: 'ENERGY',
            value: recipe.calories ?? '320 kcal',
          ),
        ],
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
