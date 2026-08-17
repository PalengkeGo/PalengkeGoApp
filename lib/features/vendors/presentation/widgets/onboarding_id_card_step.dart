import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';

class OnboardingIdCardStep extends StatelessWidget {
  final String? selectedIdType;
  final String? idCardFile;
  final ValueChanged<String> onIdTypeChanged;
  final VoidCallback onUploadIdCard;

  const OnboardingIdCardStep({
    super.key,
    this.selectedIdType,
    this.idCardFile,
    required this.onIdTypeChanged,
    required this.onUploadIdCard,
  });

  @override
  Widget build(BuildContext context) {
    // Complete list of Philippine government IDs from Figma
    final idTypes = [
      'Unified Multi-Purpose Identification (UMID) Card',
      'Social Security System (SSS) Card',
      'Government Service Insurance System (GSIS) e-Card',
      'Land Transportation Office (LTO) Driver\'s License',
      'Philippine Postal ID',
      'Philippine Passport',
      'PhilHealth ID',
      'PhilID / ePhilID (PhilSys)',
      'Professional Regulation Commission (PRC) ID',
      'Alien Certification of Registration',
      'Foreign Passport',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (idCardFile != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Stack(
                children: [
                  if (idCardFile!.toLowerCase().endsWith('.jpg') ||
                      idCardFile!.toLowerCase().endsWith('.jpeg') ||
                      idCardFile!.toLowerCase().endsWith('.png'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: AdaptiveImage(idCardFile, fit: BoxFit.cover),
                      ),
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.description,
                            size: 40,
                            color: AppTheme.muted,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              idCardFile!.split('/').last,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: onUploadIdCard,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ...List.generate(idTypes.length, (index) {
            final type = idTypes[index];
            final isSelected = selectedIdType == type;
            return GestureDetector(
              onTap: () => onIdTypeChanged(type),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.primaryGreen,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
