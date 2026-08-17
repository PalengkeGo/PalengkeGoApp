import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/features/vendors/data/firebase_license_renewal_repository.dart';
import 'package:palengkego/features/vendors/data/mock_license_renewal_repository.dart';
import 'package:palengkego/features/vendors/domain/license_renewal.dart';
import 'package:palengkego/features/vendors/domain/license_renewal_repository.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/core/services/app_services.dart';

final licenseRenewalRepositoryProvider = Provider<LicenseRenewalRepository>((
  ref,
) {
  final firebaseEnabled = ref.watch(firebaseEnabledProvider);
  if (firebaseEnabled) {
    final firestore = ref.watch(firestoreProvider);
    return FirebaseLicenseRenewalRepository(firestore);
  }
  return MockLicenseRenewalRepository();
});

/// Fetches the active (latest) renewal for the logged in vendor.
final activeRenewalProvider = FutureProvider.autoDispose<LicenseRenewal?>((
  ref,
) async {
  final stall = ref.watch(vendorStallProvider);
  final repo = ref.watch(licenseRenewalRepositoryProvider);
  return repo.getActiveRenewal(stall.stallId);
});

/// Fetches the full history of renewals.
final renewalHistoryProvider = FutureProvider.autoDispose<List<LicenseRenewal>>(
  (ref) async {
    final stall = ref.watch(vendorStallProvider);
    final repo = ref.watch(licenseRenewalRepositoryProvider);
    return repo.getRenewalHistory(stall.stallId);
  },
);

/// Computes the current license status based on the active renewal's status and periodEnd.
final computedLicenseStatusProvider = Provider.autoDispose<LicenseStatus>((
  ref,
) {
  final activeRenewalAsync = ref.watch(activeRenewalProvider);

  return activeRenewalAsync.when(
    data: (renewal) {
      if (renewal == null) {
        return LicenseStatus.active; // Fallback if no history
      }

      if (renewal.status == LicenseRenewalStatus.pending) {
        return LicenseStatus.pending;
      }

      final now = DateTime.now();
      final difference = renewal.periodEnd.difference(now).inDays;

      if (difference > 30) {
        return LicenseStatus.active;
      } else if (difference >= 0) {
        return LicenseStatus.expiringSoon;
      } else if (difference >= -30) {
        return LicenseStatus.expired;
      } else {
        return LicenseStatus.suspended;
      }
    },
    loading: () => LicenseStatus.active, // Default while loading
    error: (e, st) => LicenseStatus.active,
  );
});

class LicenseRenewalProcessor extends Notifier<void> {
  @override
  void build() {}

  Future<void> submitAndPay(LicenseRenewal renewal) async {
    try {
      final repo = ref.read(licenseRenewalRepositoryProvider);

      // 1. Submit initial request (pending)
      await repo.submitRenewal(renewal);

      // Status remains pending awaiting MEPO approval
      AppServices.scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Renewal request submitted! Awaiting MEPO Approval.',
            style: TextStyle(),
          ),
          backgroundColor: AppTheme.primaryGreen,
          duration: Duration(seconds: 4),
        ),
      );

      // Refresh providers
      ref.invalidate(activeRenewalProvider);
      ref.invalidate(renewalHistoryProvider);
    } catch (e) {
      AppServices.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Failed to process renewal: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }
}

final licenseRenewalProcessorProvider =
    NotifierProvider<LicenseRenewalProcessor, void>(
      LicenseRenewalProcessor.new,
    );
