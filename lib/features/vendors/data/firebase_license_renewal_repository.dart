import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:palengkego/features/vendors/domain/license_renewal.dart';
import 'package:palengkego/features/vendors/domain/license_renewal_repository.dart';

/// Firestore implementation of [LicenseRenewalRepository].
///
/// Collection: `licenseRenewals/{renewalId}`
class FirebaseLicenseRenewalRepository implements LicenseRenewalRepository {
  FirebaseLicenseRenewalRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('licenseRenewals');

  @override
  Future<LicenseRenewal?> getActiveRenewal(String stallId) async {
    // Get the most recently submitted renewal
    final snap = await _col
        .where('stallId', isEqualTo: stallId)
        .orderBy('submittedAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return LicenseRenewal.fromFirestore(doc.data(), id: doc.id);
  }

  @override
  Future<List<LicenseRenewal>> getRenewalHistory(String stallId) async {
    final snap = await _col
        .where('stallId', isEqualTo: stallId)
        .orderBy('submittedAt', descending: true)
        .get();

    return snap.docs
        .map((doc) => LicenseRenewal.fromFirestore(doc.data(), id: doc.id))
        .toList();
  }

  @override
  Future<LicenseRenewal> submitRenewal(LicenseRenewal renewal) async {
    final ref = _col.doc();
    final saved = LicenseRenewal(
      renewalId: ref.id,
      stallId: renewal.stallId,
      vendorUid: renewal.vendorUid,
      vendorName: renewal.vendorName,
      periodStart: renewal.periodStart,
      periodEnd: renewal.periodEnd,
      amountPaid: renewal.amountPaid,
      paymentMethod: renewal.paymentMethod,
      paymentReferenceId: renewal.paymentReferenceId,
      submittedAt: DateTime.now(),
      status: LicenseRenewalStatus.pending,
    );

    await ref.set(saved.toFirestore());
    return saved;
  }

  @override
  Future<void> updateRenewalStatus(
    String renewalId,
    LicenseRenewalStatus status, {
    String? rejectionReason,
    String? reviewedBy,
  }) async {
    final updates = <String, dynamic>{'status': status.name};

    if (status == LicenseRenewalStatus.paid) {
      updates['paidAt'] = DateTime.now().toIso8601String();
    }

    if (status == LicenseRenewalStatus.approved ||
        status == LicenseRenewalStatus.rejected) {
      updates['reviewedAt'] = DateTime.now().toIso8601String();
      if (reviewedBy != null) updates['reviewedBy'] = reviewedBy;
    }

    if (rejectionReason != null) {
      updates['rejectionReason'] = rejectionReason;
    }

    await _col.doc(renewalId).update(updates);
  }
}
