import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Checkbox + Terms & Privacy Policy link for the registration form.
class RegistrationTermsRow extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool> onChanged;

  const RegistrationTermsRow({
    super.key,
    required this.accepted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: accepted,
          onChanged: (val) => onChanged(val ?? false),
          activeColor: AppTheme.primaryGreen,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final url = Uri.parse('https://palengkego.com/terms');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              } else {
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Terms & Privacy Policy'),
                    content: const SingleChildScrollView(
                      child: Text(
                        'By registering, you agree to our Terms & Privacy Policy.\n\n'
                        'Please note: Stall holder contact numbers are collected and displayed to allow direct customer communication.\n\n'
                        'For full terms, please visit https://palengkego.com/terms',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: AppTheme.primaryGreen),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                ),
                children: [
                  TextSpan(text: 'By registering, you agree to our '),
                  TextSpan(
                    text: 'Terms & Privacy Policy',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
