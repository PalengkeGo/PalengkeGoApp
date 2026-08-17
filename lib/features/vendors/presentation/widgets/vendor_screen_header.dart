import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class VendorScreenHeader extends StatelessWidget {
  const VendorScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final canGoBack = onBack != null || Navigator.of(context).canPop();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: canGoBack
                ? GestureDetector(
                    onTap: onBack ?? () => Navigator.maybePop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.scaffoldBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: trailing == null
                ? const SizedBox.shrink()
                : Center(child: trailing),
          ),
        ],
      ),
    );
  }
}
