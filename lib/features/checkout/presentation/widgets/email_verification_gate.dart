import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';

/// Email-verification gate for checkout (Firebase mode only).
///
/// Email/password registrations must verify their inbox before placing
/// orders; Google sign-in accounts always carry `emailVerified == true` and
/// pass naturally (no special-casing needed). The server-side
/// `place-order` edge function enforces the same check on its own.
///
/// Returns true when the customer may proceed to place the order.
Future<bool> ensureEmailVerified(BuildContext context, WidgetRef ref) async {
  if (!ref.read(firebaseEnabledProvider)) return true; // mock/dev mode
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.emailVerified) return true;

  // The flag only updates server-side after the link is clicked — reload.
  await user.reload();
  if (user.emailVerified) return true;

  if (!context.mounted) return false;
  final verified = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _EmailVerificationDialog(user: user),
  );
  return verified ?? false;
}

class _EmailVerificationDialog extends StatefulWidget {
  const _EmailVerificationDialog({required this.user});

  final User user;

  @override
  State<_EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<_EmailVerificationDialog> {
  bool _sending = false;
  bool _checking = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await widget.user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Check your inbox.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send verification email: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    await widget.user.reload();
    if (!mounted) return;
    setState(() => _checking = false);
    if (widget.user.emailVerified) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email not verified yet. Click the link in your inbox, then try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify your email'),
      content: const Text(
        'You need to confirm your email address before placing orders. '
        'We sent a verification link to your inbox.',
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: _resend,
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Resend verification email'),
        ),
        FilledButton(
          onPressed: _checking ? null : _checkVerified,
          child: _checking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('I\'ve verified — continue'),
        ),
      ],
    );
  }
}