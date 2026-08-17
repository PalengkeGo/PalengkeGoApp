import 'package:palengkego/features/vendors/domain/license_renewal.dart';

/// Contract for vendor stall license renewal operations.
abstract class LicenseRenewalRepository {
  /// Submit a new license renewal request (initializes doc with status=pending).
  Future<LicenseRenewal> submitRenewal(LicenseRenewal renewal);

  /// Get the renewal history for a vendor stall (ordered by submittedAt desc).
  Future<List<LicenseRenewal>> getRenewalHistory(String stallId);

  /// Get the most recent/active renewal for a stall.
  Future<LicenseRenewal?> getActiveRenewal(String stallId);

  /// Update the status of a license renewal.
  /// Typically called after payment success (pending -> paid)
  /// or admin review (paid -> approved/rejected).
  Future<void> updateRenewalStatus(
    String renewalId,
    LicenseRenewalStatus status, {
    String? rejectionReason,
    String? reviewedBy,
  });
}
