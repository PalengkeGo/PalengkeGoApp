import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/core/widgets/app_screen_header.dart';

class VendorAccountDetailsScreen extends StatefulWidget {
  const VendorAccountDetailsScreen({super.key});

  @override
  State<VendorAccountDetailsScreen> createState() =>
      _VendorAccountDetailsScreenState();
}

class _VendorAccountDetailsScreenState
    extends State<VendorAccountDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  bool _isPasswordSectionExpanded = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Juan Dela Cruz');
    _phoneController = TextEditingController(text: '09171234567');
    _emailController = TextEditingController(
      text: 'juan.delacruz@palengkego.ph',
    );

    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      allowedRoles: {UserRole.vendor},
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              const AppScreenHeader(title: 'Account Details'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header: Personal Info
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Full Name
                        _buildLabel('Full Name'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _nameController,
                          hint: 'Enter full name',
                          keyboardType: TextInputType.name,
                        ),
                        const SizedBox(height: 20),

                        // Phone Number
                        _buildLabel('Phone Number'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _phoneController,
                          hint: 'Enter phone number',
                          keyboardType: TextInputType.phone,
                          prefixText: '+63 ',
                        ),
                        const SizedBox(height: 20),

                        // Email Address
                        _buildLabel('Email Address'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _emailController,
                          hint: 'Enter email address',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 28),

                        // Section Header: Security
                        const Text(
                          'Security',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Change Password Expansion Card
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: const Text(
                                'Change Password',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              leading: const Icon(
                                Icons.lock_outline_rounded,
                                color: AppTheme.primaryGreen,
                              ),
                              onExpansionChanged: (expanded) {
                                setState(() {
                                  _isPasswordSectionExpanded = expanded;
                                });
                              },
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Divider(
                                        color: AppTheme.border,
                                        height: 1,
                                      ),
                                      const SizedBox(height: 16),

                                      // Current Password
                                      _buildLabel('Current Password'),
                                      const SizedBox(height: 8),
                                      _buildPasswordField(
                                        controller: _currentPasswordController,
                                        hint: 'Enter current password',
                                        obscureText: _obscureCurrent,
                                        onToggleVisibility: () {
                                          setState(() {
                                            _obscureCurrent = !_obscureCurrent;
                                          });
                                        },
                                        isRequired: _isPasswordSectionExpanded,
                                      ),
                                      const SizedBox(height: 16),

                                      // New Password
                                      _buildLabel('New Password'),
                                      const SizedBox(height: 8),
                                      _buildPasswordField(
                                        controller: _newPasswordController,
                                        hint: 'Enter new password',
                                        obscureText: _obscureNew,
                                        onToggleVisibility: () {
                                          setState(() {
                                            _obscureNew = !_obscureNew;
                                          });
                                        },
                                        isRequired: _isPasswordSectionExpanded,
                                      ),
                                      const SizedBox(height: 16),

                                      // Confirm New Password
                                      _buildLabel('Confirm New Password'),
                                      const SizedBox(height: 8),
                                      _buildPasswordField(
                                        controller: _confirmPasswordController,
                                        hint: 'Confirm new password',
                                        obscureText: _obscureConfirm,
                                        onToggleVisibility: () {
                                          setState(() {
                                            _obscureConfirm = !_obscureConfirm;
                                          });
                                        },
                                        isRequired: _isPasswordSectionExpanded,
                                        validator: (val) {
                                          if (!_isPasswordSectionExpanded) {
                                            return null;
                                          }
                                          if (val == null || val.isEmpty) {
                                            return 'Please confirm your new password';
                                          }
                                          if (val !=
                                              _newPasswordController.text) {
                                            return 'Passwords do not match';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Save Changes Button
                        GestureDetector(
                          onTap: () {
                            if (_formKey.currentState!.validate()) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppTheme.primaryGreen,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  content: const Text(
                                    'Account details successfully updated!',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                              Navigator.pop(context);
                            }
                          },
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
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
  }) {
    return AppTextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      hintStyle: const TextStyle(fontSize: 14, color: AppTheme.muted),
      fillColor: AppTheme.surface,
      borderless: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'This field is required';
        }
        if (keyboardType == TextInputType.emailAddress) {
          final emailRegExp = RegExp(
            r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
          );
          if (!emailRegExp.hasMatch(val.trim())) {
            return 'Please enter a valid email address';
          }
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required bool isRequired,
    String? Function(String?)? validator,
  }) {
    return AppTextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: AppTheme.muted),
      fillColor: Colors.white,
      borderColor: AppTheme.border,
      suffixIcon: IconButton(
        icon: Icon(
          obscureText
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: AppTheme.textSecondary,
          size: 20,
        ),
        onPressed: onToggleVisibility,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      validator:
          validator ??
          (val) {
            if (!isRequired) return null;
            if (val == null || val.isEmpty) {
              return 'This field is required';
            }
            final pwRegex = RegExp(
              r'^(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\$&*~]).{8,}$',
            );
            if (!pwRegex.hasMatch(val)) {
              return 'Must contain uppercase, number, symbol, and 8+ chars';
            }
            return null;
          },
    );
  }
}
