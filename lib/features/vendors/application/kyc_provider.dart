import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/features/vendors/data/mock_kyc_repository.dart';
import 'package:palengkego/features/vendors/data/supabase_kyc_repository.dart';
import 'package:palengkego/features/vendors/domain/kyc_repository.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/application/has_vendor_stall_provider.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/features/vendors/domain/kyc_submission.dart';
import 'package:shared_preferences/shared_preferences.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  if (supabase != null) {
    return SupabaseKycRepository(supabase);
  }
  return MockKycRepository();
});

/// Fetches the latest KYC submission for the currently logged-in user.
final userKycSubmissionProvider =
    FutureProvider.autoDispose<KycSubmission?>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) return null;
  final repo = ref.watch(kycRepositoryProvider);
  return repo.getKycStatus(user.uid);
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

      final hasRealBackend = ref.read(supabaseClientProvider) != null ||
          ref.read(firebaseEnabledProvider);

      if (hasRealBackend) {
        // Real backend: submission is an APPLICATION pending MEPO review.
        // It stays 'pending' until the admin approves or rejects.
        final notif = ref.read(notificationServiceProvider);
        notif.addNotification(
          AppNotification(
            id: 'vendor_reg_pending_${DateTime.now().millisecondsSinceEpoch}',
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
        ref.invalidate(userKycSubmissionProvider);
        return;
      }

      // Demo/mock mode: instant "approval" keeps the showcase flow intact.
      // Theatrical processing pause for demo mode only.
      await Future.delayed(const Duration(seconds: 3));

      // Persist the vendor stall flag
      await ref.read(hasVendorStallProvider.notifier).setHasVendorStall(true);

      // Keep the demo flow from showing the same approval dialog again when
      // MainScreen checks the already-approved stall on a later visit.
      final approvalUserId =
          ref.read(authProvider)?.uid ?? submission.stallHolderId;
      final prefs = await SharedPreferences.getInstance();
      final shownKey = 'kyc_approved_dialog_$approvalUserId';
      final alreadyShown = prefs.getBool(shownKey) ?? false;
      if (!alreadyShown) {
        await prefs.setBool(shownKey, true);
        ref.read(showKycSuccessDialogProvider.notifier).show();
      }

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
