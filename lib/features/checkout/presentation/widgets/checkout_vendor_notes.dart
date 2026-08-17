import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Vendor label + multi-line notes field for one vendor's order.
class CheckoutVendorNotes extends StatelessWidget {
  final String vendorName;
  final TextEditingController controller;

  const CheckoutVendorNotes({
    super.key,
    required this.vendorName,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).notesForVendor(vendorName),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        AppTextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          hintText:
              'e.g. chop the pork into small cubes, select green bananas, etc.',
          hintStyle: const TextStyle(fontSize: 14, color: AppTheme.muted),
          fillColor: AppTheme.surface,
          borderColor: AppTheme.border,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ],
    );
  }
}
