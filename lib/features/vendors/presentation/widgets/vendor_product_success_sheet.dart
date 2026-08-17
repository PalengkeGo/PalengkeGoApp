import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Success bottom sheet after saving a product.
/// [navigator] must be captured BEFORE the sheet opens — after
/// Navigator.pop(ctx) fires inside the sheet, the parent widget's context
/// may already be deactivated on Flutter Web; the pre-captured navigator
/// avoids the "deactivated widget ancestor" crash.
Future<void> showVendorProductSuccessSheet({
  required BuildContext context,
  required bool isEditMode,
  required String productName,
  required NavigatorState navigator,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 36,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isEditMode ? 'Product Updated!' : 'Product Added!',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"$productName" has been ${isEditMode ? 'updated in' : 'added to'} your inventory and is now visible to customers.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // close the sheet
                navigator
                    .pop(); // close add/edit screen (pre-captured, never stale)
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Back to Products',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
