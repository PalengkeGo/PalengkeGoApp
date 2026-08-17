import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// "Recipes" title row with the Cookbook shortcut button.
class RecipesHeader extends StatelessWidget {
  const RecipesHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Recipes',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B4332),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.cookbook),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SvgPicture.asset(
                'assets/icons/cookbook.svg',
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  AppTheme.primaryGreen,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
