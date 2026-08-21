/// License renewal status.
enum LicenseRenewalStatus { pending, paid, approved, rejected, expired }

/// A vendor's stall license renewal application.
///
/// Matches the LICENSE_RENEWALS ERD entity.
/// Collection path: `licenseRenewals/{renewalId}`
///
/// Vendors submit this via the app to renew their stall license.
/// MEPO (Admin) reviews it on the Admin Web Portal.
class LicenseRenewal {
  const LicenseRenewal({
    required this.renewalId,
    required this.stallId,
    required this.vendorUid,
    required this.vendorName,
    required this.periodStart,
    required this.periodEnd,
    required this.amountPaid,
    required this.paymentMethod,
    this.paymentReferenceId,
    this.documentUrl,
    required this.submittedAt,
    this.status = LicenseRenewalStatus.pending,
    this.paidAt,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
  });

  /// Firestore document ID.
  final String renewalId;

  /// UID of the vendor stall.
  final String stallId;

  /// UID of the vendor user.
  final String vendorUid;

  /// Name of the stall at the time of renewal request.
  final String vendorName;

  /// The start date of the renewed license.
  final DateTime periodStart;

  /// The end date of the renewed license (usually 1 year from periodStart).
  final DateTime periodEnd;

  /// Total fee amount paid (PHP).
  final double amountPaid;

  /// Payment method (e.g., paymongo_gcash, paymongo_card, cash_at_office).
  final String paymentMethod;

  /// External payment gateway reference (e.g., PayMongo checkout session id).
  final String? paymentReferenceId;

  /// Uploaded renewal document URL (Supabase storage).
  final String? documentUrl;

  /// Current status of the renewal.
  final LicenseRenewalStatus status;

  /// When the renewal request was initiated.
  final DateTime submittedAt;

  /// When the payment was successfully confirmed.
  final DateTime? paidAt;

  /// UID of the admin (MEPO) who reviewed the application.
  final String? reviewedBy;

  /// Date when the admin reviewed it.
  final DateTime? reviewedAt;

  /// Reason for rejection (if status == rejected).
  final String? rejectionReason;

  bool get isPending => status == LicenseRenewalStatus.pending;
  bool get isPaid => status == LicenseRenewalStatus.paid;
  bool get isApproved => status == LicenseRenewalStatus.approved;
  bool get isRejected => status == LicenseRenewalStatus.rejected;
  bool get isExpired => status == LicenseRenewalStatus.expired;

  Map<String, dynamic> toFirestore() {
    return {
      'stallId': stallId,
      'vendorUid': vendorUid,
      'vendorName': vendorName,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
      'amountPaid': amountPaid,
      'paymentMethod': paymentMethod,
      'paymentReferenceId': paymentReferenceId,
      'documentUrl': documentUrl,
      'status': status.name,
      'submittedAt': submittedAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
    };
  }

  factory LicenseRenewal.fromFirestore(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return LicenseRenewal(
      renewalId: id,
      stallId: data['stallId'] as String? ?? '',
      vendorUid: data['vendorUid'] as String? ?? '',
      vendorName: data['vendorName'] as String? ?? '',
      periodStart: data['periodStart'] != null
          ? DateTime.parse(data['periodStart'] as String)
          : DateTime.now(),
      periodEnd: data['periodEnd'] != null
          ? DateTime.parse(data['periodEnd'] as String)
          : DateTime.now().add(const Duration(days: 365)),
      amountPaid: (data['amountPaid'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] as String? ?? 'cash',
      paymentReferenceId: data['paymentReferenceId'] as String?,
      documentUrl: data['documentUrl'] as String?,
      status: LicenseRenewalStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String? ?? 'pending'),
        orElse: () => LicenseRenewalStatus.pending,
      ),
      submittedAt: data['submittedAt'] != null
          ? DateTime.parse(data['submittedAt'] as String)
          : DateTime.now(),
      paidAt: data['paidAt'] != null
          ? DateTime.parse(data['paidAt'] as String)
          : null,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: data['reviewedAt'] != null
          ? DateTime.parse(data['reviewedAt'] as String)
          : null,
      rejectionReason: data['rejectionReason'] as String?,
    );
  }
}
