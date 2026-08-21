import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_onboarding_screen.dart';
import 'package:palengkego/features/vendors/presentation/widgets/onboarding_business_info_step.dart';
import 'package:palengkego/features/vendors/presentation/widgets/onboarding_registered_name_step.dart';

void main() {
  group('OnboardingBusinessInfoStep', () {
    testWidgets('renders contact number field and strips non-digits', (
      tester,
    ) async {
      final registeredName = TextEditingController();
      final phone = TextEditingController(text: '9');
      addTearDown(registeredName.dispose);
      addTearDown(phone.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingBusinessInfoStep(
              registeredNameController: registeredName,
              phoneController: phone,
              selectedCategory: '',
              onCategoryChanged: (_) {},
              mayorsPermitFile: null,
              sanitaryPermitFile: null,
              fireCertificationFile: null,
              marketClearanceFile: null,
              onUploadMayorsPermit: () {},
              onUploadSanitaryPermit: () {},
              onUploadFireCertification: () {},
              onUploadMarketClearance: () {},
            ),
          ),
        ),
      );

      expect(find.text('Contact Number *'), findsOneWidget);
      expect(find.text('+63 '), findsOneWidget);
      expect(phone.text, '9');

      await tester.enterText(find.byType(TextField).last, '0917 123-4567');
      expect(phone.text, '9171234567');

      await tester.enterText(find.byType(TextField).last, '91712345678');
      expect(phone.text, '9171234567');
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
          'Please enter stall name, contact number, select a category, and upload all permits.',
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
