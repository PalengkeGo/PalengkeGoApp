/// KYC submission status.
enum KycSubmissionStatus { pending, approved, rejected }

/// A vendor's KYC (Know Your Customer) document submission.
///
/// Matches the KYC_SUBMISSIONS ERD entity.
/// Collection path: `kycSubmissions/{kycId}`
///
/// The vendor submits this from the VendorOnboardingScreen.
/// The admin reviews it on the Admin Web portal and updates the status.
class KycSubmission {
  const KycSubmission({
    required this.kycId,
    required this.stallHolderId,
    this.mayorPermitUrl,
    this.sanitaryPermitUrl,
    this.fireCertificationUrl,
    this.marketClearanceUrl,
    this.mayorPermitNumber,
    this.sanitaryPermitNumber,
    this.fireCertNumber,
    this.marketClearanceNumber,
    this.validIdPhotoUrl,
    this.selfieUrl,
    required this.submittedAt,
    this.status = KycSubmissionStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
  });

  /// Firestore document ID.
  final String kycId;

  /// UID of the vendor who submitted this application.
  final String stallHolderId;

  // ── Permit document URLs (Firebase Storage) ────────────────────────────────
  final String? mayorPermitUrl;
  final String? sanitaryPermitUrl;
  final String? fireCertificationUrl;
  final String? marketClearanceUrl;

  // ── Optional permit reference numbers ─────────────────────────────────────
  final String? mayorPermitNumber;
  final String? sanitaryPermitNumber;
  final String? fireCertNumber;
  final String? marketClearanceNumber;

  // ── Identity verification ──────────────────────────────────────────────────
  final String? validIdPhotoUrl;
  final String? selfieUrl;

  final DateTime submittedAt;
  final KycSubmissionStatus status;

  /// UID of the admin who reviewed this submission (set by admin portal).
  final String? reviewedBy;
  final DateTime? reviewedAt;

  /// Populated when status == rejected.
  final String? rejectionReason;

  bool get isPending => status == KycSubmissionStatus.pending;
  bool get isApproved => status == KycSubmissionStatus.approved;
  bool get isRejected => status == KycSubmissionStatus.rejected;

  Map<String, dynamic> toFirestore() {
    return {
      'stallHolderId': stallHolderId,
      'mayorPermitUrl': mayorPermitUrl,
      'sanitaryPermitUrl': sanitaryPermitUrl,
      'fireCertificationUrl': fireCertificationUrl,
      'marketClearanceUrl': marketClearanceUrl,
      'mayorPermitNumber': mayorPermitNumber,
      'sanitaryPermitNumber': sanitaryPermitNumber,
      'fireCertNumber': fireCertNumber,
      'marketClearanceNumber': marketClearanceNumber,
      'validIdPhotoUrl': validIdPhotoUrl,
      'selfieUrl': selfieUrl,
      'submittedAt': submittedAt.toIso8601String(),
      'status': status.name,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
    };
  }

  factory KycSubmission.fromFirestore(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return KycSubmission(
      kycId: id,
      stallHolderId: data['stallHolderId'] as String? ?? '',
      mayorPermitUrl: data['mayorPermitUrl'] as String?,
      sanitaryPermitUrl: data['sanitaryPermitUrl'] as String?,
      fireCertificationUrl: data['fireCertificationUrl'] as String?,
      marketClearanceUrl: data['marketClearanceUrl'] as String?,
      mayorPermitNumber: data['mayorPermitNumber'] as String?,
      sanitaryPermitNumber: data['sanitaryPermitNumber'] as String?,
      fireCertNumber: data['fireCertNumber'] as String?,
      marketClearanceNumber: data['marketClearanceNumber'] as String?,
      validIdPhotoUrl: data['validIdPhotoUrl'] as String?,
      selfieUrl: data['selfieUrl'] as String?,
      submittedAt: data['submittedAt'] != null
          ? DateTime.parse(data['submittedAt'] as String)
          : DateTime.now(),
      status: KycSubmissionStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String? ?? 'pending'),
        orElse: () => KycSubmissionStatus.pending,
      ),
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: data['reviewedAt'] != null
          ? DateTime.parse(data['reviewedAt'] as String)
          : null,
      rejectionReason: data['rejectionReason'] as String?,
    );
  }
}
