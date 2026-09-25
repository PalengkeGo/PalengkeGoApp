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
    this.documentStoragePaths = const {},
    required this.submittedAt,
    this.status = KycSubmissionStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    this.stallName,
    this.stallNumber,
    this.floorNumber,
    this.category,
    this.contactNumber,
    this.ownerName,
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

  /// Durable Supabase Storage paths per document field (audit 2026-09-13 C1),
  /// e.g. `{'marketClearance': '{uid}/marketClearance_1699.jpg'}`.
  ///
  /// The *Url fields above may hold short-lived display URLs; this map is the
  /// durable reference — readers mint a 1-hour URL on demand via
  /// SupabaseStorageService.mintSignedUrl. Long-lived signed URLs are never
  /// persisted anymore.
  final Map<String, String> documentStoragePaths;

  final DateTime submittedAt;
  final KycSubmissionStatus status;

  /// UID of the admin who reviewed this submission (set by admin portal).
  final String? reviewedBy;
  final DateTime? reviewedAt;

  /// Populated when status == rejected.
  final String? rejectionReason;

  // ── Optional stall details captured during onboarding ──────────────────────
  final String? stallName;
  final String? stallNumber;
  final String? floorNumber;
  final String? category;
  final String? contactNumber;
  final String? ownerName;

  bool get isPending => status == KycSubmissionStatus.pending;
  bool get isApproved => status == KycSubmissionStatus.approved;
  bool get isRejected => status == KycSubmissionStatus.rejected;

  Map<String, dynamic> toSupabase() {
    final map = <String, dynamic>{
      'stall_holder_id': stallHolderId,
      'mayor_permit_url': mayorPermitUrl ?? '',
      'sanitary_permit_url': sanitaryPermitUrl ?? '',
      'fire_certification_url': fireCertificationUrl ?? '',
      'market_clearance_url': marketClearanceUrl ?? '',
      'mayor_permit_number': mayorPermitNumber,
      'sanitary_permit_number': sanitaryPermitNumber,
      'fire_cert_number': fireCertNumber,
      'market_clearance_number': marketClearanceNumber,
      'valid_id_photo_url': validIdPhotoUrl ?? '',
      'selfie_url': selfieUrl ?? '',
      'submitted_at': submittedAt.toIso8601String(),
      'status': status.name,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
    };
    if (kycId.isNotEmpty) {
      map['kyc_id'] = kycId;
    }
    return map;
  }

  factory KycSubmission.fromSupabase(Map<String, dynamic> data) {
    return KycSubmission(
      kycId: data['kyc_id'] as String? ?? '',
      stallHolderId: data['stall_holder_id'] as String? ?? '',
      mayorPermitUrl: data['mayor_permit_url'] as String?,
      sanitaryPermitUrl: data['sanitary_permit_url'] as String?,
      fireCertificationUrl: data['fire_certification_url'] as String?,
      marketClearanceUrl: data['market_clearance_url'] as String?,
      mayorPermitNumber: data['mayor_permit_number'] as String?,
      sanitaryPermitNumber: data['sanitary_permit_number'] as String?,
      fireCertNumber: data['fire_cert_number'] as String?,
      marketClearanceNumber: data['market_clearance_number'] as String?,
      validIdPhotoUrl: data['valid_id_photo_url'] as String?,
      selfieUrl: data['selfie_url'] as String?,
      submittedAt: data['submitted_at'] != null
          ? DateTime.parse(data['submitted_at'] as String)
          : DateTime.now(),
      status: KycSubmissionStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String? ?? 'pending'),
        orElse: () => KycSubmissionStatus.pending,
      ),
      reviewedBy: data['reviewed_by'] as String?,
      reviewedAt: data['reviewed_at'] != null
          ? DateTime.parse(data['reviewed_at'] as String)
          : null,
      rejectionReason: data['rejection_reason'] as String?,
    );
  }

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
      'documentStoragePaths': documentStoragePaths,
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
      documentStoragePaths:
          (data['documentStoragePaths'] as Map?)?.cast<String, String>() ??
              const {},
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
