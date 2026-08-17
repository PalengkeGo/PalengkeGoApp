import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/presentation/widgets/registration_form_fields.dart';
import 'package:palengkego/features/auth/presentation/widgets/registration_address_placeholder.dart';
import 'package:palengkego/features/auth/presentation/widgets/registration_terms_row.dart';
import 'package:palengkego/features/auth/presentation/widgets/registration_bottom_action_bar.dart';
import 'package:palengkego/features/auth/presentation/widgets/registration_input_formatters.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _termsAccepted = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  DeliveryAddress? _selectedAddress;

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // Form validators cover all field-level checks.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms & Privacy Policy.'),
        ),
      );
      return;
    }

    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set your delivery location first.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firstName = _firstNameController.text.trim();
      final surname = _surnameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;
      final name = '$firstName $surname';
      await ref.read(authProvider.notifier).register(email, password, name);

      // Save the selected address if any
      if (_selectedAddress != null) {
        ref
            .read(preferencesProvider.notifier)
            .updateAddress(
              primaryAddress: _selectedAddress!.primaryAddress,
              streetAddress: _selectedAddress!.streetAddress,
              notes: _selectedAddress!.notes,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Registration successful!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      if (!mounted) return;

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.primaryGreen,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            // Scrollable form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header text
                      Image.asset('assets/images/logonobg.png', height: 80),
                      const SizedBox(height: 16),
                      const Text(
                        'Create an Account',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                          height: 1.2,
                          letterSpacing: -0.75,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Join PalengkeGo for fresh market delivery.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textSecondary,
                          height: 1.43,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      // Name
                      Row(
                        children: [
                          Expanded(
                            child: RegistrationTextField(
                              label: 'First Name',
                              hintText: 'First name',
                              prefixIcon: Icons.person_outline_rounded,
                              controller: _firstNameController,
                              // Allow letters, spaces, hyphens, and periods (for names like "Ma. Elena")
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r"[a-zA-ZÀ-ÿ .\-']"),
                                ),
                              ],
                              textCapitalization: TextCapitalization.words,
                              validator: (v) {
                                final val = (v ?? '').trim();
                                if (val.isEmpty) {
                                  return 'First name is required';
                                }
                                if (val.length < 2) return 'Too short';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: RegistrationTextField(
                              label: 'Surname',
                              hintText: 'Surname',
                              prefixIcon: Icons.person_outline_rounded,
                              controller: _surnameController,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r"[a-zA-ZÀ-ÿ .\-']"),
                                ),
                              ],
                              textCapitalization: TextCapitalization.words,
                              validator: (v) {
                                final val = (v ?? '').trim();
                                if (val.isEmpty) return 'Surname is required';
                                if (val.length < 2) return 'Too short';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Email
                      RegistrationTextField(
                        label: 'Email Address',
                        hintText: 'Enter your email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        controller: _emailController,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                          LowercaseFormatter(),
                        ],
                        validator: (v) {
                          final val = (v ?? '').trim();
                          if (val.isEmpty) return 'Email is required';
                          final ok = RegExp(
                            r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
                          ).hasMatch(val);
                          return ok ? null : 'Enter a valid email address';
                        },
                      ),
                      const SizedBox(height: 16),
                      // Phone
                      RegistrationTextField(
                        label: 'Phone Number',
                        hintText: 'xxx xxx xxxx',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        controller: _phoneController,
                        prefixText: '+63 ',
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                          PhoneSpaceFormatter(),
                        ],
                        validator: (v) {
                          final val = (v ?? '').replaceAll(RegExp(r'\D'), '');
                          if (val.isEmpty) return 'Phone number is required';
                          if (val.length < 10) {
                            return 'Enter a 10-digit PH number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Password
                      RegistrationPasswordField(
                        label: 'Password',
                        hintText: 'Create a password',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onToggleVisibility: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        validator: (v) {
                          final val = v ?? '';
                          if (val.isEmpty) return 'Password is required';
                          if (val.length < 8) return 'At least 8 characters';
                          if (!RegExp(r'[A-Z]').hasMatch(val)) {
                            return 'Add an uppercase letter';
                          }
                          if (!RegExp(r'[0-9]').hasMatch(val)) {
                            return 'Add a number';
                          }
                          if (!RegExp(r'[!@#&*~^%]').hasMatch(val)) {
                            return 'Add a special character (!@#&*~^%)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Confirm Password
                      RegistrationPasswordField(
                        label: 'Confirm Password',
                        hintText: 'Confirm your password',
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        onToggleVisibility: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        validator: (v) {
                          if ((v ?? '').isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Set Address Button
                      RegistrationAddressPlaceholder(
                        selectedAddress: _selectedAddress,
                        onSelected: (address) {
                          setState(() => _selectedAddress = address);
                        },
                      ),
                      const SizedBox(height: 24),
                      // Terms
                      RegistrationTermsRow(
                        accepted: _termsAccepted,
                        onChanged: (val) {
                          setState(() => _termsAccepted = val);
                        },
                      ),
                      const SizedBox(height: 24),
                      RegistrationBottomActionBar(
                        isLoading: _isLoading,
                        onRegister: _handleRegister,
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
    );
  }
}
