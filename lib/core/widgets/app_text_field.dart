import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palengkego/core/theme/app_theme.dart';

/// Builds an [InputDecoration] on top of the global inputDecorationTheme
/// (app_theme.dart) with per-instance overrides. Border defaults replicate the
/// global theme (white fill, r12, grey.shade300 side, green focus ring) unless
/// overridden. Error borders are only added when [errorBorderColor] is set.
InputDecoration appInputDecoration({
  String? labelText,
  String? hintText,
  String? helperText,
  String? errorText,
  Widget? prefixIcon,
  BoxConstraints? prefixIconConstraints,
  String? prefixText,
  TextStyle? prefixStyle,
  Widget? suffixIcon,
  String? suffixText,
  TextStyle? labelStyle,
  TextStyle? floatingLabelStyle,
  TextStyle? hintStyle,
  TextStyle? errorStyle,
  Color? fillColor,
  EdgeInsetsGeometry? contentPadding,
  double borderRadius = 12,
  Color? borderColor,
  double borderWidth = 1,
  bool borderless = false,
  bool showFocusedBorder = true,
  Color? focusedBorderColor = AppTheme.primaryGreen,
  double focusedBorderWidth = 1,
  Color? errorBorderColor,
  double errorBorderWidth = 1,
}) {
  final side = borderless
      ? BorderSide.none
      : BorderSide(
          color: borderColor ?? Colors.grey.shade300,
          width: borderWidth,
        );
  final base = OutlineInputBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    borderSide: side,
  );
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    errorText: errorText,
    prefixIcon: prefixIcon,
    prefixIconConstraints: prefixIconConstraints,
    prefixText: prefixText,
    prefixStyle: prefixStyle,
    suffixIcon: suffixIcon,
    suffixText: suffixText,
    labelStyle: labelStyle,
    floatingLabelStyle: floatingLabelStyle,
    hintStyle: hintStyle,
    errorStyle: errorStyle,
    filled: true,
    fillColor: fillColor ?? Colors.white,
    contentPadding:
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: base,
    enabledBorder: base,
    focusedBorder: showFocusedBorder
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: focusedBorderColor ?? AppTheme.primaryGreen,
              width: focusedBorderWidth,
            ),
          )
        : null,
    errorBorder: errorBorderColor == null
        ? null
        : OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: errorBorderColor,
              width: errorBorderWidth,
            ),
          ),
    focusedErrorBorder: errorBorderColor == null
        ? null
        : OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: errorBorderColor,
              width: focusedBorderWidth,
            ),
          ),
  );
}

/// [TextFormField] with the shared [appInputDecoration] defaults so call sites
/// only pass what differs from the global inputDecorationTheme.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final int? maxLines;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final BoxConstraints? prefixIconConstraints;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final TextStyle? prefixStyle;
  final TextStyle? labelStyle;
  final TextStyle? floatingLabelStyle;
  final TextStyle? hintStyle;
  final TextStyle? errorStyle;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final bool borderless;
  final bool showFocusedBorder;
  final Color? focusedBorderColor;
  final double focusedBorderWidth;
  final Color? errorBorderColor;
  final double errorBorderWidth;

  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    this.onFieldSubmitted,
    this.maxLines,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.prefixIconConstraints,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.prefixStyle,
    this.labelStyle,
    this.floatingLabelStyle,
    this.hintStyle,
    this.errorStyle,
    this.fillColor,
    this.contentPadding,
    this.borderRadius = 12,
    this.borderColor,
    this.borderWidth = 1,
    this.borderless = false,
    this.showFocusedBorder = true,
    this.focusedBorderColor = AppTheme.primaryGreen,
    this.focusedBorderWidth = 1,
    this.errorBorderColor,
    this.errorBorderWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      validator: validator,
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      // Flutter asserts that obscured fields are single-line; a null maxLines
      // slips past that check, so coerce obscured fields to exactly one line.
      maxLines: obscureText ? 1 : maxLines,
      textAlign: textAlign,
      textCapitalization: textCapitalization,
      style: style,
      decoration: appInputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        prefixIconConstraints: prefixIconConstraints,
        prefixText: prefixText,
        prefixStyle: prefixStyle,
        suffixIcon: suffixIcon,
        suffixText: suffixText,
        labelStyle: labelStyle,
        floatingLabelStyle: floatingLabelStyle,
        hintStyle: hintStyle,
        errorStyle: errorStyle,
        fillColor: fillColor,
        contentPadding: contentPadding,
        borderRadius: borderRadius,
        borderColor: borderColor,
        borderWidth: borderWidth,
        borderless: borderless,
        showFocusedBorder: showFocusedBorder,
        focusedBorderColor: focusedBorderColor,
        focusedBorderWidth: focusedBorderWidth,
        errorBorderColor: errorBorderColor,
        errorBorderWidth: errorBorderWidth,
      ),
    );
  }
}
