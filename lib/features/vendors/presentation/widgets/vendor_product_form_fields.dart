import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';

class VendorProductImagePicker extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onTap;

  const VendorProductImagePicker({
    super.key,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AdaptiveImage(
                  imageUrl,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: const Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: AppTheme.muted,
                  ),
                ),
              )
            else ...[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppTheme.primaryGreen,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Upload Photo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap to select a photo of the product',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ],
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Tap to change image',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryGreen.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class VendorProductUnitPicker extends StatelessWidget {
  final bool? isPieceUnit;
  final ValueChanged<bool> onChanged;

  const VendorProductUnitPicker({
    super.key,
    required this.isPieceUnit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isPieceUnit == false
                      ? AppTheme.primaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isPieceUnit == false
                      ? [
                          const BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.1),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Per Kilogram (kg)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isPieceUnit == false
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: isPieceUnit == false
                        ? Colors.white
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isPieceUnit == true
                      ? AppTheme.primaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isPieceUnit == true
                      ? [
                          const BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.1),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Per Piece (pc)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isPieceUnit == true
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: isPieceUnit == true
                        ? Colors.white
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VendorProductCategorySelector extends StatelessWidget {
  final String selectedCategory;
  final VoidCallback onTap;

  const VendorProductCategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedCategory.isEmpty ? 'Select Category' : selectedCategory,
              style: TextStyle(
                fontSize: 14,
                color: selectedCategory.isEmpty
                    ? AppTheme.muted
                    : const Color(0xFF111827),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

class VendorProductDiscountBanner extends StatelessWidget {
  final double? discountedPrice;

  const VendorProductDiscountBanner({super.key, this.discountedPrice});

  @override
  Widget build(BuildContext context) {
    final price = discountedPrice;
    if (price == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.local_offer_rounded,
              color: Color(0xFF16A34A),
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              'Discounted Price:',
              style: TextStyle(fontSize: 13, color: AppTheme.success),
            ),
            const Spacer(),
            Text(
              '₱${price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF15803D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VendorProductLabel extends StatelessWidget {
  final String text;

  const VendorProductLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
    );
  }
}

class VendorProductTextField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? prefixText;
  final String? suffixText;
  final void Function(String)? onChanged;

  const VendorProductTextField({
    super.key,
    required this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.prefixText,
    this.suffixText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
      decoration: appInputDecoration(
        hintText: hint,
        prefixText: prefixText,
        suffixText: suffixText,
        hintStyle: const TextStyle(fontSize: 14, color: AppTheme.muted),
        fillColor: AppTheme.surface,
        borderless: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
