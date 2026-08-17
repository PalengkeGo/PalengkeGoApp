import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class StallSettingsSaveButton extends StatelessWidget {
  final VoidCallback onSave;

  const StallSettingsSaveButton({super.key, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSave,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Save Changes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
