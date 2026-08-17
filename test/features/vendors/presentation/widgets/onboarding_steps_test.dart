import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_onboarding_screen.dart';
import 'package:palengkego/features/vendors/presentation/widgets/onboarding_phone_step.dart';
import 'package:palengkego/features/vendors/presentation/widgets/onboarding_registered_name_step.dart';

void main() {
  group('OnboardingPhoneStep', () {
    testWidgets('formats phone input to 10 digits and OTP to 6 digits', (
      tester,
    ) async {
      final phone = TextEditingController();
      final otp = TextEditingController();
      var otpRequests = 0;
      addTearDown(phone.dispose);
      addTearDown(otp.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingPhoneStep(
              phoneController: phone,
              otpController: otp,
              onSendOtp: () => otpRequests++,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, '0917123456789');
      await tester.enterText(find.byType(TextField).last, '12ab34567');

      expect(phone.text, '0917123456');
      expect(otp.text, '123456');
      expect(find.text('Phone Number *'), findsOneWidget);
      expect(find.text('Phone Number Verification'), findsOneWidget);
      expect(find.text('+63'), findsOneWidget);
    });

    testWidgets('fires onSendOtp when Send OTP is tapped', (tester) async {
      final phone = TextEditingController();
      final otp = TextEditingController();
      var otpRequests = 0;
      addTearDown(phone.dispose);
      addTearDown(otp.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingPhoneStep(
              phoneController: phone,
              otpController: otp,
              onSendOtp: () => otpRequests++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Send OTP'));
      await tester.pump();

      expect(otpRequests, 1);
    });
  });

  group('OnboardingRegisteredNameStep', () {
    testWidgets('renders the four name fields and accepts input', (
      tester,
    ) async {
      final lastName = TextEditingController();
      final firstName = TextEditingController();
      final suffix = TextEditingController();
      final middleName = TextEditingController();
      addTearDown(lastName.dispose);
      addTearDown(firstName.dispose);
      addTearDown(suffix.dispose);
      addTearDown(middleName.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingRegisteredNameStep(
              lastNameController: lastName,
              firstNameController: firstName,
              suffixController: suffix,
              middleNameController: middleName,
            ),
          ),
        ),
      );

      for (final label in [
        'Last Name *',
        'First Name *',
        'Suffix (Optional)',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.enterText(find.byType(TextField).at(0), 'Dela Cruz');
      await tester.enterText(find.byType(TextField).at(1), 'Juan');
      await tester.enterText(find.byType(TextField).at(2), 'Jr.');
      await tester.enterText(find.byType(TextField).at(3), 'Santos');

      expect(lastName.text, 'Dela Cruz');
      expect(firstName.text, 'Juan');
      expect(suffix.text, 'Jr.');
      expect(middleName.text, 'Santos');
    });
  });

  group('VendorOnboardingScreen navigation guards', () {
    testWidgets('blocks step 0 when required names are missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appConfigProvider.overrideWithValue(const AppConfig())],
          child: const MaterialApp(home: VendorOnboardingScreen()),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Please fill all required fields.'), findsOneWidget);
      expect(find.text('Registered Name'), findsOneWidget);

      // Let the snackbar timer finish so no timers are pending.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('advances to business info then blocks the empty form', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appConfigProvider.overrideWithValue(const AppConfig())],
          child: const MaterialApp(home: VendorOnboardingScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'Dela Cruz');
      await tester.enterText(find.byType(TextField).at(1), 'Juan');
      await tester.enterText(find.byType(TextField).at(3), 'Santos');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Business Information'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(
        find.text(
          'Please enter stall name, select a category, and upload all permits.',
        ),
        findsOneWidget,
      );
      expect(find.text('Business Information'), findsOneWidget);

      // Let the snackbar timer finish so no timers are pending.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
