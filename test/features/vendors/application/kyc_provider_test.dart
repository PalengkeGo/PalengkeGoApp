import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/auth/application/has_vendor_stall_provider.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/features/vendors/application/kyc_provider.dart';
import 'package:palengkego/features/vendors/data/mock_kyc_repository.dart';
import 'package:palengkego/features/vendors/domain/kyc_repository.dart';
import 'package:palengkego/features/vendors/domain/kyc_submission.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleSubmission = KycSubmission(
    kycId: 'kyc-test-1',
    stallHolderId: 'vendor-001',
    mayorPermitUrl: 'https://example.com/mayor.pdf',
    validIdPhotoUrl: 'https://example.com/id.png',
    selfieUrl: 'https://example.com/selfie.png',
    submittedAt: DateTime.now(),
    status: KycSubmissionStatus.pending,
  );

  group('kycRepositoryProvider backend switch', () {
    test('without Firebase resolves to the mock KYC repository', () {
      final container = ProviderContainer(
        overrides: [appConfigProvider.overrideWithValue(const AppConfig())],
      );
      addTearDown(container.dispose);

      expect(container.read(kycRepositoryProvider), isA<MockKycRepository>());
    });
  });

  group('KycProcessor.submitAndProcess', () {
    late ProviderContainer container;
    late _RecordingKycRepository repo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = _RecordingKycRepository();
      container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig()),
          kycRepositoryProvider.overrideWithValue(repo),
          notificationServiceProvider.overrideWithValue(
            NotificationService(isTest: true),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    testWidgets(
      'submits KYC, then activates stall, dialog, notification & snackbar',
      (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              scaffoldMessengerKey: AppServices.scaffoldMessengerKey,
              home: const Scaffold(body: SizedBox()),
            ),
          ),
        );

        container
            .read(kycProcessorProvider.notifier)
            .submitAndProcess(sampleSubmission);

        // Mock processing is in-flight: nothing activated yet.
        await tester.pump(const Duration(milliseconds: 400));
        expect(container.read(hasVendorStallProvider), isFalse);
        expect(container.read(showKycSuccessDialogProvider), isFalse);

        // Past the mock 3-second registration delay.
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();

        expect(repo.submitted, sampleSubmission);
        expect(container.read(hasVendorStallProvider), isTrue);
        expect(container.read(showKycSuccessDialogProvider), isTrue);

        final notifications = container.read(notificationServiceProvider).all;
        expect(
          notifications.any((n) => n.title == 'Welcome, Stall Holder! 🎉'),
          isTrue,
        );

        expect(
          find.text('Stall Holder Registration Successful! 🎉 Welcome!'),
          findsOneWidget,
        );

        // Let the 4-second snackbar timer finish so no timers are pending.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    test(
      'repository failure keeps stall flags off and pushes failure notification',
      () async {
        repo.throwOnSubmit = true;

        await container
            .read(kycProcessorProvider.notifier)
            .submitAndProcess(sampleSubmission);

        expect(repo.submitted, sampleSubmission);
        expect(container.read(hasVendorStallProvider), isFalse);
        expect(container.read(showKycSuccessDialogProvider), isFalse);

        final notifications = container.read(notificationServiceProvider).all;
        expect(
          notifications.any(
            (n) => n.title == 'Stall Holder Registration Failed',
          ),
          isTrue,
        );

        // Let the async stall-flag load settle so it never completes after disposal.
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
    );
  });
}

class _RecordingKycRepository implements KycRepository {
  _RecordingKycRepository();

  KycSubmission? submitted;
  bool throwOnSubmit = false;

  @override
  Future<KycSubmission> submitKyc(KycSubmission submission) async {
    submitted = submission;
    if (throwOnSubmit) {
      throw Exception('KYC backend unreachable');
    }
    return submission;
  }

  @override
  Future<KycSubmission?> getKycStatus(String stallId) async => null;
}
