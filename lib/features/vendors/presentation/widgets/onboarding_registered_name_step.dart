import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

class OnboardingRegisteredNameStep extends StatelessWidget {
  final TextEditingController lastNameController;
  final TextEditingController firstNameController;
  final TextEditingController suffixController;
  final TextEditingController middleNameController;

  const OnboardingRegisteredNameStep({
    super.key,
    required this.lastNameController,
    required this.firstNameController,
    required this.suffixController,
    required this.middleNameController,
  });

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefix,
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
          textCapitalization: TextCapitalization.words,
          keyboardType: keyboardType,
          maxLines: maxLines,
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
            controller: lastNameController,
            label: 'Last Name *',
            hint: 'Input',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: firstNameController,
            label: 'First Name *',
            hint: 'Input',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: suffixController,
            label: 'Suffix (Optional)',
            hint: 'Input',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: middleNameController,
            label: 'Middle Name *',
            hint: 'Input',
          ),
        ],
      ),
    );
  }
}
