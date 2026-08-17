import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';

class OnboardingBusinessInfoStep extends StatelessWidget {
  final TextEditingController registeredNameController;
  final TextEditingController? blockNumberController;
  final TextEditingController? stallNumberController;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final String? mayorsPermitFile;
  final String? sanitaryPermitFile;
  final String? fireCertificationFile;
  final String? marketClearanceFile;
  final VoidCallback onUploadMayorsPermit;
  final VoidCallback onUploadSanitaryPermit;
  final VoidCallback onUploadFireCertification;
  final VoidCallback onUploadMarketClearance;

  const OnboardingBusinessInfoStep({
    super.key,
    required this.registeredNameController,
    this.blockNumberController,
    this.stallNumberController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.mayorsPermitFile,
    required this.sanitaryPermitFile,
    required this.fireCertificationFile,
    required this.marketClearanceFile,
    required this.onUploadMayorsPermit,
    required this.onUploadSanitaryPermit,
    required this.onUploadFireCertification,
    required this.onUploadMarketClearance,
  });

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextCapitalization textCapitalization = TextCapitalization.words,
    String? prefixText,
    TextInputType keyboardType = TextInputType.text,
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
          textCapitalization: textCapitalization,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          decoration: appInputDecoration(
            hintText: hint,
            prefixText: prefixText,
            prefixStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            hintStyle: const TextStyle(fontSize: 14, color: AppTheme.muted),
            fillColor: const Color(0xFFF3F4F6),
            borderless: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadField({
    required String label,
    required String hint,
    required String? fileName,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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
          if (fileName != null)
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Stack(
                children: [
                  if (fileName.toLowerCase().endsWith('.jpg') ||
                      fileName.toLowerCase().endsWith('.jpeg') ||
                      fileName.toLowerCase().endsWith('.png'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: AdaptiveImage(fileName, fit: BoxFit.cover),
                      ),
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.description,
                            size: 40,
                            color: AppTheme.muted,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              fileName.split('/').last.split('#').last,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFCBD5E1),
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.upload_file,
                      size: 24,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Add Attachment',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Supported formats: PDF, DOC, DOCX, JPG, PNG',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Registered Name of the Stall
          _buildTextField(
            controller: registeredNameController,
            label: 'Registered Name of the Stall *',
            hint: 'Enter your stall name',
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),

          // Block & Stall Numbers Row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: blockNumberController ?? TextEditingController(),
                  label: 'Block Number *',
                  hint: '',
                  prefixText: 'Block ',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: stallNumberController ?? TextEditingController(),
                  label: 'Stall Number *',
                  hint: '',
                  prefixText: 'Stall ',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Category Dropdown
          const Text(
            'Stall Category *',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedCategory.isEmpty ? null : selectedCategory,
                hint: const Text(
                  'Select a category',
                  style: TextStyle(fontSize: 14, color: AppTheme.muted),
                ),
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppTheme.muted,
                ),
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                items:
                    [
                      'Fresh Fish',
                      'Dried Fish',
                      'Meat',
                      'Chicken',
                      'Fruits',
                      'Vegetables',
                      'Maritatas',
                      'Sari-Sari',
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    onCategoryChanged(newValue);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Mayor's Permit with upload
          _buildUploadField(
            label: 'Mayor\'s Permit *',
            hint: '+ Upload (0/1)',
            fileName: mayorsPermitFile,
            onTap: onUploadMayorsPermit,
          ),
          const SizedBox(height: 20),

          // Sanitary Permit with upload
          _buildUploadField(
            label: 'Sanitary Permit *',
            hint: '+ Upload (0/1)',
            fileName: sanitaryPermitFile,
            onTap: onUploadSanitaryPermit,
          ),
          const SizedBox(height: 20),

          // Fire Certification with upload
          _buildUploadField(
            label: 'Fire Certification *',
            hint: '+ Upload (0/1)',
            fileName: fireCertificationFile,
            onTap: onUploadFireCertification,
          ),
          const SizedBox(height: 20),

          // Market Clearance with upload
          _buildUploadField(
            label: 'Market Clearance *',
            hint: '+ Upload (0/1)',
            fileName: marketClearanceFile,
            onTap: onUploadMarketClearance,
          ),
        ],
      ),
    );
  }
}
