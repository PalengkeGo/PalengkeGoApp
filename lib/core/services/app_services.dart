import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Global keys for app-level UI services.
///
/// Using these keys avoids all "deactivated widget's ancestor" crashes
/// that occur when calling ScaffoldMessenger.of(context) or Navigator.of(context)
/// after an async gap on Flutter Web — the key always points to the live root
/// state, regardless of what the current route is doing.
abstract class AppServices {
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Show a floating snackbar from anywhere in the app without a BuildContext.
  /// Deferred to the next frame so it never fires mid-rebuild or during
  /// Riverpod invalidation cascades that temporarily deactivate widget elements.
  static void showSnackBar(
    String message, {
    Color backgroundColor = AppTheme.primaryGreen,
    Duration duration = const Duration(seconds: 3),
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scaffoldMessengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            backgroundColor: backgroundColor,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            margin: const EdgeInsets.all(16),
            duration: duration,
          ),
        );
    });
  }

  /// Show an error snackbar.
  static void showError(String message) =>
      showSnackBar(message, backgroundColor: const Color(0xFFEF4444));
}
