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

  /// Formats raw auth & network exceptions into user-friendly messages.
  static String formatAuthError(Object error) {
    final raw = error.toString();

    if (raw.contains('missing-password')) {
      return 'Please enter your password.';
    }
    if (raw.contains('wrong-password') ||
        raw.contains('invalid-credential') ||
        raw.contains('user-mismatch')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (raw.contains('user-not-found')) {
      return 'No account found with this email. Please register first.';
    }
    if (raw.contains('email-already-in-use') ||
        raw.contains('email-already-exists')) {
      return 'An account with this email already exists. Please log in.';
    }
    if (raw.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (raw.contains('weak-password')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }
    if (raw.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many attempts. Please try again in a few minutes.';
    }
    if (raw.contains('network-request-failed') ||
        raw.contains('SocketException') ||
        raw.contains('ClientException')) {
      return 'Unable to connect. Please check your internet connection.';
    }
    if (raw.contains('popup_closed') || raw.contains('cancelled')) {
      return 'Sign-in cancelled.';
    }

    final cleaned = raw
        .replaceAll(RegExp(r'\[.*?\]\s*'), '')
        .replaceAll('Exception: ', '')
        .trim();

    return cleaned.isNotEmpty
        ? cleaned
        : 'An error occurred. Please try again.';
  }

  /// Show an auth error snackbar with friendly formatting and red background.
  static void showAuthError(Object error) => showError(formatAuthError(error));

  /// Formats upload exceptions into clean user-friendly messages.
  static String formatUploadError(Object error) {
    final raw = error.toString();
    if (raw.contains('ClientException') ||
        raw.contains('Failed to fetch') ||
        raw.contains('SocketException')) {
      return 'Upload failed: Connection error. Please try again.';
    }
    if (raw.contains('413') || raw.contains('too large')) {
      return 'Upload failed: File is too large. Please select a smaller file.';
    }
    if (raw.contains('401') ||
        raw.contains('unauthenticated') ||
        raw.contains('Sign in required')) {
      return 'Upload failed: Please log in again.';
    }
    final cleaned = raw
        .replaceAll(RegExp(r'\[.*?\]\s*'), '')
        .replaceAll('Exception: ', '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : 'Upload failed. Please try again.';
  }

  /// Show an upload error snackbar with red background.
  static void showUploadError(Object error) =>
      showError(formatUploadError(error));
}
