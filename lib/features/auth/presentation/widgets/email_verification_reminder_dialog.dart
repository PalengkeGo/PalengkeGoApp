import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';

class EmailVerificationReminderDialog extends ConsumerStatefulWidget {
  const EmailVerificationReminderDialog({
    required this.email,
    required this.onGotIt,
    required this.onCheckVerification,
    super.key,
  });

  final String email;
  final Future<void> Function() onGotIt;
  final Future<bool> Function() onCheckVerification;

  @override
  ConsumerState<EmailVerificationReminderDialog> createState() =>
      _EmailVerificationReminderDialogState();
}

class _EmailVerificationReminderDialogState
    extends ConsumerState<EmailVerificationReminderDialog> {
  bool _busy = false;
  bool _notVerifiedYet = false;

  void _close() {
    final route = ModalRoute.of(context);
    if (route != null) Navigator.of(context).removeRoute(route);
  }

  Future<void> _gotIt() async {
    setState(() => _busy = true);
    try {
      await widget.onGotIt();
    } finally {
      if (mounted) _close();
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _busy = true;
      _notVerifiedYet = false;
    });
    final verified = await widget.onCheckVerification();
    if (!mounted) return;
    if (verified) {
      _close();
    } else {
      setState(() {
        _busy = false;
        _notVerifiedYet = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next?.isVerified == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _close();
        });
      }
    });

    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        title: Column(
          children: [
            Image.asset(
              'assets/images/palengkego-logo.png',
              width: 68,
              height: 68,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            const Text(
              'Welcome to PalengkeGo!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please verify your email address to secure your account:',
            ),
            const SizedBox(height: 6),
            Text(
              widget.email,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'We sent you a verification link. Your personal information is '
              'handled securely and used to support your PalengkeGo account.',
            ),
            if (_notVerifiedYet) ...[
              const SizedBox(height: 12),
              const Text(
                'We have not received verification yet. Open the link in your '
                'email, then return here and check again.',
                style: TextStyle(color: AppTheme.primaryGreen),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _gotIt,
            child: const Text('Got it'),
          ),
          FilledButton(
            onPressed: _busy ? null : _checkVerification,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            child: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text("I've verified"),
          ),
        ],
      ),
    );
  }
}
