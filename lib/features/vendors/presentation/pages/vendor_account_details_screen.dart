import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/core/widgets/app_screen_header.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';

class VendorAccountDetailsScreen extends ConsumerStatefulWidget {
  const VendorAccountDetailsScreen({super.key});

  @override
  ConsumerState<VendorAccountDetailsScreen> createState() =>
      _VendorAccountDetailsScreenState();
}

class _VendorAccountDetailsScreenState
    extends ConsumerState<VendorAccountDetailsScreen> {
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
    final user = ref.read(authProvider);
    _nameController = TextEditingController(
      text: user?.displayName ?? 'Stall Holder',
    );
    final phone = user?.phoneNumber ?? '';
    _phoneController = TextEditingController(
      text: phone.startsWith('+63') ? phone.substring(3).trim() : phone,
    );
    _emailController = TextEditingController(text: user?.email ?? '');

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

  Future<void> _saveChanges(bool isGoogle) async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider);
    final newName = _nameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final formattedPhone = rawPhone.isEmpty
        ? ''
        : (rawPhone.startsWith('+63') ? rawPhone : '+63 $rawPhone');

    // 1. Password change validation & execution
    bool passwordChanged = false;
    if (!isGoogle &&
        _isPasswordSectionExpanded &&
        _newPasswordController.text.isNotEmpty) {
      if (_currentPasswordController.text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFFEF4444),
            content: Text('Please enter your current password'),
          ),
        );
        return;
      }
      try {
        await ref
            .read(authRepositoryProvider)
            .changePassword(
              _currentPasswordController.text,
              _newPasswordController.text,
            );
        passwordChanged = true;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        final err = e.toString().toLowerCase();
        final msg =
            (err.contains('wrong-password') ||
                err.contains('invalid-credential'))
            ? 'Current password is incorrect. Please try again.'
            : 'Failed to update password: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
            content: Text(msg),
          ),
        );
        return;
      }
    }

    // 2. Update Supabase user profile
    final client = ref.read(supabaseClientProvider);
    if (client != null && user != null) {
      try {
        await client
            .from('users')
            .update({'full_name': newName, 'phone_number': formattedPhone})
            .eq('user_id', user.uid)
            .select('user_id')
            .single();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save account details: $e')),
        );
        return;
      }
    }
    await ref.read(authProvider.notifier).reloadUser();

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primaryGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          passwordChanged
              ? 'Account details and password successfully updated!'
              : 'Account details successfully updated!',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final fbUser = ref.watch(firebaseEnabledProvider)
        ? ref.watch(firebaseAuthProvider).currentUser
        : null;
    final isGoogle =
        user?.isGoogleUser == true ||
        (fbUser != null &&
            fbUser.providerData.any((p) => p.providerId == 'google.com'));

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

                        if (isGoogle) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.account_circle_outlined,
                                      size: 28,
                                      color: Color(0xFF4285F4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Text(
                                            'Google Account Linked',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 16,
                                            color: Color(0xFF10B981),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Signed in via Google (${user?.email ?? 'Google'}). Your security and password are managed by your Google account.',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Change Password Expansion Card for Email/Password Accounts
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
                                          controller:
                                              _currentPasswordController,
                                          hint: 'Enter current password',
                                          obscureText: _obscureCurrent,
                                          onToggleVisibility: () {
                                            setState(() {
                                              _obscureCurrent =
                                                  !_obscureCurrent;
                                            });
                                          },
                                          isRequired:
                                              _isPasswordSectionExpanded,
                                          validator: (val) {
                                            if (_isPasswordSectionExpanded &&
                                                _newPasswordController
                                                    .text
                                                    .isNotEmpty &&
                                                (val == null || val.isEmpty)) {
                                              return 'Enter your current password';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),

                                        // New Password
                                        _buildLabel('New Password'),
                                        const SizedBox(height: 8),
                                        _buildPasswordField(
                                          controller: _newPasswordController,
                                          hint:
                                              'Enter new password (min. 6 characters)',
                                          obscureText: _obscureNew,
                                          onToggleVisibility: () {
                                            setState(() {
                                              _obscureNew = !_obscureNew;
                                            });
                                          },
                                          isRequired:
                                              _isPasswordSectionExpanded,
                                          validator: (val) {
                                            if (_isPasswordSectionExpanded &&
                                                (val != null &&
                                                    val.isNotEmpty &&
                                                    val.length < 6)) {
                                              return 'Must be at least 6 characters';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),

                                        // Confirm New Password
                                        _buildLabel('Confirm New Password'),
                                        const SizedBox(height: 8),
                                        _buildPasswordField(
                                          controller:
                                              _confirmPasswordController,
                                          hint: 'Confirm new password',
                                          obscureText: _obscureConfirm,
                                          onToggleVisibility: () {
                                            setState(() {
                                              _obscureConfirm =
                                                  !_obscureConfirm;
                                            });
                                          },
                                          isRequired:
                                              _isPasswordSectionExpanded,
                                          validator: (val) {
                                            if (!_isPasswordSectionExpanded ||
                                                _newPasswordController
                                                    .text
                                                    .isEmpty) {
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
                        ],
                        const SizedBox(height: 40),

                        // Save Changes Button
                        GestureDetector(
                          onTap: () => _saveChanges(isGoogle),
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
