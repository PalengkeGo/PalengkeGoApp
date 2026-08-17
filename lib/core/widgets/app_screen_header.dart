import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.size = 40,
    this.titleSize = 20,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double size;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack ?? () => Navigator.maybePop(context),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: AppTheme.scaffoldBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: trailing == null
                ? const SizedBox.shrink()
                : Center(child: trailing),
          ),
        ],
      ),
    );
  }
}
