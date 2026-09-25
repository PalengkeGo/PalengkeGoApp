import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/vendors/domain/kyc_submission.dart';

void main() {
  test('KycSubmission toSupabase and fromSupabase round-trip preserves fields', () {
    final now = DateTime.now();
    final submission = KycSubmission(
      kycId: 'kyc-uuid-123',
      stallHolderId: 'user-firebase-456',
      mayorPermitUrl: 'https://storage/mayor.jpg',
      sanitaryPermitUrl: 'https://storage/sanitary.jpg',
      fireCertificationUrl: 'https://storage/fire.jpg',
      marketClearanceUrl: 'https://storage/market.jpg',
      mayorPermitNumber: 'MP-001',
      sanitaryPermitNumber: 'SP-002',
      fireCertNumber: 'FC-003',
      marketClearanceNumber: 'MC-004',
      validIdPhotoUrl: 'https://storage/id.jpg',
      selfieUrl: '',
      submittedAt: now,
      status: KycSubmissionStatus.pending,
      stallName: 'Mang Juan Veggies',
      stallNumber: '12',
      floorNumber: '1',
      category: 'Vegetables',
      contactNumber: '+639123456789',
      ownerName: 'Juan Dela Cruz',
    );

    final map = submission.toSupabase();
    expect(map['kyc_id'], 'kyc-uuid-123');
    expect(map['stall_holder_id'], 'user-firebase-456');
    expect(map['mayor_permit_url'], 'https://storage/mayor.jpg');
    expect(map['status'], 'pending');

    final restored = KycSubmission.fromSupabase(map);
    expect(restored.kycId, submission.kycId);
    expect(restored.stallHolderId, submission.stallHolderId);
    expect(restored.mayorPermitUrl, submission.mayorPermitUrl);
    expect(restored.status, submission.status);
  });
}
