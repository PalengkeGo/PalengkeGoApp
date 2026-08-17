import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Bottom-sheet option picker for product category / subcategory.
/// Calls [onSelected] when an option is tapped, then closes itself.
Future<void> showVendorProductPickerSheet({
  required BuildContext context,
  required String title,
  required List<String> options,
  required String selected,
  required ValueChanged<String> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              ...options.map((option) {
                final isSelected = option == selected;
                return ListTile(
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppTheme.primaryGreen,
                        )
                      : null,
                  title: Text(
                    option,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : const Color(0xFF374151),
                    ),
                  ),
                  onTap: () {
                    onSelected(option);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    },
  );
}
