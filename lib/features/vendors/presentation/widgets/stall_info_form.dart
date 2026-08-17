import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

class StallInfoForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController locationController;
  final String selectedCategory;
  final List<String> categories;
  final ValueChanged<String> onCategoryChanged;

  const StallInfoForm({
    super.key,
    required this.nameController,
    required this.descriptionController,
    required this.locationController,
    required this.selectedCategory,
    required this.categories,
    required this.onCategoryChanged,
  });

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF475569),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool readOnly = false,
    Widget? suffixIcon,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return AppTextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      textCapitalization: textCapitalization,
      style: TextStyle(
        fontSize: 14,
        color: readOnly ? AppTheme.textSecondary : const Color(0xFF1E293B),
      ),
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: AppTheme.muted),
      fillColor: readOnly ? AppTheme.surfaceContainerLow : AppTheme.surface,
      suffixIcon: suffixIcon,
      borderless: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'This field is required';
        }
        return null;
      },
    );
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Select Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                ...categories.map((category) {
                  return ListTile(
                    title: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    trailing: selectedCategory == category
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppTheme.primaryGreen,
                          )
                        : null,
                    onTap: () {
                      onCategoryChanged(category);
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stall Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),

        // Stall Name
        _buildLabel('Stall Name'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: nameController,
          hint: 'Enter stall name',
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 20),

        // Stall Description
        _buildLabel('Description'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: descriptionController,
          hint: 'Enter stall description',
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 20),

        // Category Dropdown
        _buildLabel('Category'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showCategoryPicker(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedCategory,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Stall & Block Location
        _buildLabel('Stall & Block Number (Location)'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: locationController,
          hint: 'e.g. Block 3 | Stall 4',
          readOnly: false,
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }
}
