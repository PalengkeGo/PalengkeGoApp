import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Labeled text field used across the registration form.
class RegistrationTextField extends StatelessWidget {
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextEditingController? controller;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const RegistrationTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.controller,
    this.prefixText,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        AppTextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          hintText: hintText,
          prefixText: prefixText,
          hintStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.muted,
          ),
          prefixIcon: Icon(prefixIcon, size: 18, color: AppTheme.muted),
          fillColor: AppTheme.surface,
          borderColor: AppTheme.border,
          focusedBorderWidth: 1.5,
          errorBorderColor: const Color(0xFFEF4444),
          errorBorderWidth: 1,
          errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ],
    );
  }
}

/// Labeled password field with a visibility toggle.
class RegistrationPasswordField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleVisibility;
  final String? Function(String?)? validator;

  const RegistrationPasswordField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.obscureText,
    required this.onToggleVisibility,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        AppTextField(
          controller: controller,
          obscureText: obscureText,
          textInputAction: TextInputAction.next,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.muted,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(Icons.lock_outline, size: 16, color: AppTheme.muted),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 0,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: AppTheme.textSecondary,
            ),
            onPressed: onToggleVisibility,
          ),
          fillColor: Colors.white,
          borderColor: AppTheme.border,
          focusedBorderWidth: 1.5,
          errorBorderColor: const Color(0xFFEF4444),
          errorBorderWidth: 1,
          errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
        ),
      ],
    );
  }
}
