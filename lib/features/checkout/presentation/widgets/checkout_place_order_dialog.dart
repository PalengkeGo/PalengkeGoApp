import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Confirmation dialog before placing an order. Resolves true on confirm.
Future<bool?> showCheckoutPlaceOrderDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        AppLocalizations.of(context).placeOrder,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryGreen,
        ),
      ),
      content: const Text(
        'Are you sure you want to place this order? This action cannot be undone.',
        style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            AppLocalizations.of(context).cancel,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: AppTheme.primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            AppLocalizations.of(context).confirm,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
