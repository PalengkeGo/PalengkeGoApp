import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:palengkego/features/vendors/domain/kyc_repository.dart';
import 'package:palengkego/features/vendors/domain/kyc_submission.dart';

/// Firestore implementation of [KycRepository].
///
/// Collection: `kycSubmissions/{kycId}`
///
/// Note: Document uploads (permit images) are handled by the caller via
/// Firebase Storage before constructing the [KycSubmission] with signed URLs.
class FirebaseKycRepository implements KycRepository {
  FirebaseKycRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('kycSubmissions');

  @override
  Future<KycSubmission> submitKyc(KycSubmission submission) async {
    final ref = _col.doc();
    final saved = KycSubmission(
      kycId: ref.id,
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
    await ref.set(saved.toFirestore());
    return saved;
  }

  @override
  Future<KycSubmission?> getKycStatus(String stallId) async {
    final snap = await _col
        .where('stallHolderId', isEqualTo: stallId)
        .orderBy('submittedAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return KycSubmission.fromFirestore(doc.data(), id: doc.id);
  }
}
