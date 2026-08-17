import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/core/services/app_services.dart';

import 'package:palengkego/features/vendors/presentation/widgets/onboarding_business_info_step.dart';
import 'package:palengkego/features/vendors/presentation/widgets/onboarding_registered_name_step.dart';
import 'package:palengkego/features/vendors/presentation/widgets/onboarding_id_card_step.dart';
import 'package:palengkego/features/vendors/presentation/widgets/onboarding_phone_step.dart';
import 'package:palengkego/features/vendors/presentation/widgets/onboarding_bottom_buttons.dart';
import 'package:palengkego/features/vendors/domain/kyc_submission.dart';
import 'package:palengkego/features/vendors/application/kyc_provider.dart';
import 'package:palengkego/core/utils/image_picker_helper.dart';

/// Vendor Onboarding Screen
/// Multi-step flow for vendors to register and start selling.
///
/// Steps:
/// 1. Business Information
/// 2. Registered Name
/// 3. ID Card Type
/// 4. Phone Number
///
/// Note: Field validation is disabled for development testing.
class VendorOnboardingScreen extends ConsumerStatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  ConsumerState<VendorOnboardingScreen> createState() =>
      _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState
    extends ConsumerState<VendorOnboardingScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Form data (no validation for dev)
  final _registeredNameController = TextEditingController();
  final _blockNumberController = TextEditingController();
  final _stallNumberController = TextEditingController();
  final _mayorsPermitController = TextEditingController();
  final _sanitaryPermitController = TextEditingController();
  final _fireCertificationController = TextEditingController();
  final _marketClearanceController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  // Registered name fields
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _middleNameController = TextEditingController();

  // ID card fields
  final _idNumberController = TextEditingController();
  String? _selectedIdType;

  // File upload placeholders (for dev, just text)
  String? _mayorsPermitFile;
  String? _sanitaryPermitFile;
  String? _fireCertificationFile;
  String? _marketClearanceFile;

  String _selectedCategory = '';
  String? _idCardFile;

  final List<String> _steps = [
    'Registered Name',
    'Business Information',
    'ID Card Type',
    'Phone Number',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _registeredNameController.dispose();
    _mayorsPermitController.dispose();
    _sanitaryPermitController.dispose();
    _fireCertificationController.dispose();
    _marketClearanceController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _lastNameController.dispose();
    _firstNameController.dispose();
    _suffixController.dispose();
    _middleNameController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  void _nextStep() async {
    // Validation
    if (_currentStep == 0) {
      if (_lastNameController.text.trim().isEmpty ||
          _firstNameController.text.trim().isEmpty ||
          _middleNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields.')),
        );
        return;
      }
    } else if (_currentStep == 1) {
      if (_registeredNameController.text.trim().isEmpty ||
          _selectedCategory.isEmpty ||
          _mayorsPermitFile == null ||
          _sanitaryPermitFile == null ||
          _fireCertificationFile == null ||
          _marketClearanceFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enter stall name, select a category, and upload all permits.',
            ),
          ),
        );
        return;
      }
    } else if (_currentStep == 2) {
      if (_selectedIdType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an ID Card Type.')),
        );
        return;
      }
      if (_idCardFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload an ID Card photo.')),
        );
        return;
      }
    }

    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Last step - submit KYC then go to vendor dashboard
      if (_phoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your phone number.')),
        );
        return;
      }

      final uid = ref.read(authProvider)?.uid ?? 'stall holder-001';

      final submission = KycSubmission(
        kycId: '', // generated by repo
        stallHolderId: uid,
        mayorPermitUrl: _mayorsPermitFile ?? '',
        sanitaryPermitUrl: _sanitaryPermitFile ?? '',
        fireCertificationUrl: _fireCertificationFile ?? '',
        marketClearanceUrl: _marketClearanceFile ?? '',
        mayorPermitNumber: _mayorsPermitController.text,
        sanitaryPermitNumber: _sanitaryPermitController.text,
        fireCertNumber: _fireCertificationController.text,
        marketClearanceNumber: _marketClearanceController.text,
        validIdPhotoUrl: _idCardFile ?? '',
        selfieUrl: '', // Not implemented in UI yet
        submittedAt: DateTime.now(),
        status: KycSubmissionStatus.pending,
      );
      final processor = ref.read(kycProcessorProvider.notifier);
      // 1. Immediately dismiss to home screen
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);

      // 2. Show toast globally since context will be unmounted
      AppServices.scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('MEPO is processing your request, please wait.'),
          duration: Duration(seconds: 5),
        ),
      );

      // 3. Trigger background processing on KycProcessor notifier
      processor.submitAndProcess(submission);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _onUploadMayorsPermit() async {
    final file = await ImagePickerHelper.pickImage(context);
    if (file != null) {
      setState(() {
        _mayorsPermitFile = file.path;
        _mayorsPermitController.text = file.path
            .split('/')
            .last
            .split('#')
            .last;
      });
    }
  }

  Future<void> _onUploadSanitaryPermit() async {
    final file = await ImagePickerHelper.pickImage(context);
    if (file != null) {
      setState(() {
        _sanitaryPermitFile = file.path;
        _sanitaryPermitController.text = file.path
            .split('/')
            .last
            .split('#')
            .last;
      });
    }
  }

  Future<void> _onUploadFireCertification() async {
    final file = await ImagePickerHelper.pickImage(context);
    if (file != null) {
      setState(() {
        _fireCertificationFile = file.path;
        _fireCertificationController.text = file.path
            .split('/')
            .last
            .split('#')
            .last;
      });
    }
  }

  Future<void> _onUploadMarketClearance() async {
    final file = await ImagePickerHelper.pickImage(context);
    if (file != null) {
      setState(() {
        _marketClearanceFile = file.path;
        _marketClearanceController.text = file.path
            .split('/')
            .last
            .split('#')
            .last;
      });
    }
  }

  Future<void> _onUploadIdCard() async {
    final file = await ImagePickerHelper.pickImage(context);
    if (file != null) {
      setState(() {
        _idCardFile = file.path;
      });
    }
  }

  void _onSendOtp() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your phone number first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('We sent you the code to $phone'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header with progress
            _buildHeader(),

            // Progress indicator
            _buildProgressIndicator(),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  OnboardingRegisteredNameStep(
                    lastNameController: _lastNameController,
                    firstNameController: _firstNameController,
                    suffixController: _suffixController,
                    middleNameController: _middleNameController,
                  ),
                  OnboardingBusinessInfoStep(
                    registeredNameController: _registeredNameController,
                    blockNumberController: _blockNumberController,
                    stallNumberController: _stallNumberController,
                    selectedCategory: _selectedCategory,
                    onCategoryChanged: (cat) =>
                        setState(() => _selectedCategory = cat),
                    mayorsPermitFile: _mayorsPermitFile,
                    sanitaryPermitFile: _sanitaryPermitFile,
                    fireCertificationFile: _fireCertificationFile,
                    marketClearanceFile: _marketClearanceFile,
                    onUploadMayorsPermit: _onUploadMayorsPermit,
                    onUploadSanitaryPermit: _onUploadSanitaryPermit,
                    onUploadFireCertification: _onUploadFireCertification,
                    onUploadMarketClearance: _onUploadMarketClearance,
                  ),
                  OnboardingIdCardStep(
                    selectedIdType: _selectedIdType,
                    idCardFile: _idCardFile,
                    onIdTypeChanged: (type) {
                      setState(() => _selectedIdType = type);
                      _onUploadIdCard();
                    },
                    onUploadIdCard: _onUploadIdCard,
                  ),
                  OnboardingPhoneStep(
                    phoneController: _phoneController,
                    otpController: _otpController,
                    onSendOtp: _onSendOtp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: OnboardingBottomButtons(
          currentStep: _currentStep,
          onNext: _nextStep,
          onPrevious: _previousStep,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _previousStep,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppTheme.scaffoldBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _steps[_currentStep],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(_steps.length, (index) {
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < _steps.length - 1 ? 8 : 0),
              decoration: BoxDecoration(
                color: index <= _currentStep
                    ? AppTheme.primaryGreen
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
