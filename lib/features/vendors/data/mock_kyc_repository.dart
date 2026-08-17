import 'package:palengkego/features/vendors/domain/kyc_repository.dart';
import 'package:palengkego/features/vendors/domain/kyc_submission.dart';

class MockKycRepository implements KycRepository {
  KycSubmission? _latestSubmission;

  @override
  Future<KycSubmission?> getKycStatus(String stallId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _latestSubmission;
  }

  @override
  Future<KycSubmission> submitKyc(KycSubmission submission) async {
    // Simulate upload delay.
    await Future.delayed(const Duration(milliseconds: 800));
    final saved = KycSubmission(
      kycId: 'kyc-mock-${DateTime.now().millisecondsSinceEpoch}',
      stallHolderId: submission.stallHolderId,
      mayorPermitUrl: submission.mayorPermitUrl,
      sanitaryPermitUrl: submission.sanitaryPermitUrl,
      fireCertificationUrl: submission.fireCertificationUrl,
      marketClearanceUrl: submission.marketClearanceUrl,
      mayorPermitNumber: submission.mayorPermitNumber,
      sanitaryPermitNumber: submission.sanitaryPermitNumber,
      fireCertNumber: submission.fireCertNumber,
      marketClearanceNumber: submission.marketClearanceNumber,
      validIdPhotoUrl: submission.validIdPhotoUrl,
      selfieUrl: submission.selfieUrl,
      submittedAt: DateTime.now(),
      status: KycSubmissionStatus.pending,
    );
    _latestSubmission = saved;
    return saved;
  }
}
