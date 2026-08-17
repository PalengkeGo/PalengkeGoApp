import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared back button widget matching Figma design
class BackButtonWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;

  const BackButtonWidget({super.key, this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.maybePop(context),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFF3F4F6),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          'assets/icons/back button icon.svg',
          width: 16,
          height: 16,
          colorFilter: const ColorFilter.mode(
            AppTheme.primaryGreen,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
