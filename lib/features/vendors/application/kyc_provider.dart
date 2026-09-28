import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/features/vendors/data/mock_kyc_repository.dart';
import 'package:palengkego/features/vendors/data/supabase_kyc_repository.dart';
import 'package:palengkego/features/vendors/domain/kyc_repository.dart';
import 'package:palengkego/features/auth/application/has_vendor_stall_provider.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/features/vendors/domain/kyc_submission.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  if (supabase != null) {
    return SupabaseKycRepository(supabase);
  }
  return MockKycRepository();
});

class KycSuccessNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
  void dismiss() => state = false;
}

final showKycSuccessDialogProvider = NotifierProvider<KycSuccessNotifier, bool>(
  KycSuccessNotifier.new,
);

class KycProcessor extends Notifier<void> {
  @override
  void build() {}

  Future<void> submitAndProcess(KycSubmission submission) async {
    try {
      await ref.read(kycRepositoryProvider).submitKyc(submission);

      final firebaseEnabled = ref.read(firebaseEnabledProvider);

      if (firebaseEnabled) {
        // Production truth (audit 2026-08-23 H4): submission is an
        // APPLICATION, not an activation. An admin reviews it in the portal;
        // the approveKyc callable is the single atomic moment that promotes
        // the user's role to vendor and creates the stall doc. The auth
        // stream picks the new role up automatically — no local flag is set
        // here, so the vendor UI never opens before approval is real.
        final notif = ref.read(notificationServiceProvider);
        notif.addNotification(
          AppNotification(
            id: 'vendor_reg_success_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.admin,
            target: NotificationTarget.both,
            title: 'Application Under Review ⏳',
            body:
                'Your stall holder application is still ongoing for review by MEPO. We will notify you once MEPO approves it.',
            createdAt: DateTime.now(),
          ),
        );
        notif.showLocalNotification(
          id: 'kyc_pending'.hashCode,
          title: 'Application Under Review ⏳',
          body:
              'Your stall holder application is still ongoing for review by MEPO.',
        );
        AppServices.scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'Application submitted! Your application is ongoing for review by MEPO.',
            ),
            backgroundColor: AppTheme.primaryGreen,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Demo/mock mode: instant "approval" keeps the showcase flow intact.
      // Theatrical processing pause for demo mode only.
      await Future.delayed(const Duration(seconds: 3));

      // Persist the vendor stall flag
      await ref.read(hasVendorStallProvider.notifier).setHasVendorStall(true);

      // Trigger the KYC success dialog on the home screen
      ref.read(showKycSuccessDialogProvider.notifier).show();

      // Push success notification
      final notif = ref.read(notificationServiceProvider);
      notif.addNotification(
        AppNotification(
          id: 'vendor_reg_success_${DateTime.now().millisecondsSinceEpoch}',
          type: NotificationType.admin,
          target: NotificationTarget.both,
          title: 'Application Accepted by MEPO! 🎉',
          body:
              'Your stall holder application has been accepted by MEPO. Your stall is now active!',
          createdAt: DateTime.now(),
        ),
      );
      notif.showLocalNotification(
        id: 'kyc_approved'.hashCode,
        title: 'Application Accepted by MEPO! 🎉',
        body: 'Your stall holder application has been accepted by MEPO. Welcome!',
      );

      // Show success SnackBar toast on the home screen
      AppServices.scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Stall Holder Registration Successful! 🎉 Welcome!',
            style: TextStyle(),
          ),
          backgroundColor: AppTheme.primaryGreen,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ref
          .read(notificationServiceProvider)
          .addNotification(
            AppNotification(
              id: 'vendor_reg_fail_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.admin,
              target: NotificationTarget.both,
              title: 'Stall Holder Registration Failed',
              body:
                  'There was an issue processing your stall holder application. Please try again.',
              createdAt: DateTime.now(),
            ),
          );
      AppServices.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to register: $e')),
      );
    }
  }
}

final kycProcessorProvider = NotifierProvider<KycProcessor, void>(
  KycProcessor.new,
);
