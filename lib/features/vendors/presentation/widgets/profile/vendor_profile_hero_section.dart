import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/features/vendors/domain/vendor_profile.dart';

class VendorProfileHeroSection extends StatelessWidget {
  final VendorProfile profile;

  const VendorProfileHeroSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 208,
      child: Stack(
        children: [
          Container(
            height: 160,
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black12),
                bottom: BorderSide(color: Colors.black12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.25),
                  offset: Offset(0, 4),
                  blurRadius: 4,
                ),
              ],
            ),
            child: AdaptiveImage(
              profile.imageUrl,
              fit: BoxFit.cover,
              placeholder: const AdaptiveImage(
                'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=800',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 104,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.1),
                    offset: Offset(0, 4),
                    blurRadius: 6,
                    spreadRadius: -1,
                  ),
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.1),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipOval(
                child: AdaptiveImage(
                  profile.avatarUrl,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: AppTheme.scaffoldBackground,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 40,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 12,
            child: Container(
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: profile.isOpen
                    ? const Color(0xFFDCFCE7)
                    : AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: profile.isOpen
                      ? const Color.fromRGBO(22, 163, 74, 0.2)
                      : const Color.fromRGBO(100, 116, 139, 0.2),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                profile.isOpen ? 'Open Now' : 'Closed',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: profile.isOpen
                      ? AppTheme.success
                      : AppTheme.textSecondary,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
