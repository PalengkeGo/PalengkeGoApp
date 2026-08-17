import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OnboardingPhoneStep extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController otpController;
  final VoidCallback onSendOtp;

  const OnboardingPhoneStep({
    super.key,
    required this.phoneController,
    required this.otpController,
    required this.onSendOtp,
  });

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefix,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          decoration: appInputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: AppTheme.muted),
            fillColor: const Color(0xFFF3F4F6),
            borderless: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            prefixIcon: prefix != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: prefix,
                  )
                : null,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: phoneController,
            label: 'Phone Number *',
            hint: '9xxxxxxxxx',
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            prefix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '+63',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 20, color: const Color(0xFFD1D5DB)),
                const SizedBox(width: 12),
              ],
            ),
            suffix: Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 6.0, bottom: 6.0),
              child: TextButton(
                onPressed: onSendOtp,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF7ED),
                  foregroundColor: const Color(0xFFF59E0B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text(
                  'Send OTP',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: otpController,
            label: 'Phone Number Verification',
            hint: 'Enter 6-digit code',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),
        ],
      ),
    );
  }
}
