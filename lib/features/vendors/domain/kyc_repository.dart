import 'package:palengkego/features/vendors/domain/kyc_submission.dart';

/// Contract for KYC submission operations (vendor-side only).
/// Admin review happens on the Admin Web portal.
abstract class KycRepository {
  /// Submit a new KYC application for a vendor stall.
  Future<KycSubmission> submitKyc(KycSubmission submission);

  /// Get the most recent KYC submission for a stall.
  /// Returns null if the vendor has never submitted.
  Future<KycSubmission?> getKycStatus(String stallId);
}
