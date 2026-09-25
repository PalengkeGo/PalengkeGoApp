import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Checkbox + Terms & Privacy Policy link for the registration form.
class RegistrationTermsRow extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool> onChanged;

  const RegistrationTermsRow({
    super.key,
    required this.accepted,
    required this.onChanged,
  });

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.policy_outlined,
                color: AppTheme.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Terms & Privacy Policy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  Text(
                    'PalengkeGo • Naga City',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: const SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Platform Overview',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'PalengkeGo is a digital public market platform dedicated to connecting Naga City People\'s Mall stallholders with local customers for fresh produce and market item deliveries.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  '2. User Accounts & Accuracy',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'You agree to provide accurate and truthful information, including your full name, active mobile number, and valid Naga City delivery address to ensure seamless delivery fulfillment.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  '3. Pricing & Perishable Goods',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Fresh market prices (fish, meat, vegetables, fruits) reflect daily market rates at the Naga City Public Market. Stallholders weigh items accurately upon preparing your order.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  '4. Data Privacy (RA 10173)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'In compliance with the Philippine Data Privacy Act of 2012, your personal data is collected solely for order delivery, account security, and customer service. Contact numbers and drop-off notes are shared only with assigned couriers and stallholders handling your orders.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  '5. Support & Inquiries',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'For inquiries or customer support, you may contact the Market Enterprise & Promotions Office (MEPO) or reach us directly through the PalengkeGo app Help & Support center.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Close',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              onChanged(true);
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('I Agree & Accept'),
          ),
        ],
      ),
    );
  }

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
            onTap: () => _showTermsDialog(context),
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
