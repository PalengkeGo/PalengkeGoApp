import 'package:palengkego/features/vendors/domain/license_renewal.dart';
import 'package:palengkego/features/vendors/domain/license_renewal_repository.dart';

class MockLicenseRenewalRepository implements LicenseRenewalRepository {
  /// In Philippine public markets, stall licenses run annually for the calendar
  /// year (Jan 1 to Dec 31) and renewals take place during the month of January (Jan 1–20 / Jan 31).
  final List<LicenseRenewal> _renewals = [
    LicenseRenewal(
      renewalId: 'mock-ren-seed',
      stallId: 'stall_mock_id',
      vendorUid: 'mock_uid',
      vendorName: 'Mock Stall',
      periodStart: DateTime(DateTime.now().year, 1, 1),
      periodEnd: DateTime(DateTime.now().year, 12, 31, 23, 59, 59),
      amountPaid: 5000.0,
      paymentMethod: 'cash_at_office',
      status: LicenseRenewalStatus.approved,
      submittedAt: DateTime(DateTime.now().year, 1, 10),
      paidAt: DateTime(DateTime.now().year, 1, 12),
      reviewedBy: 'admin_mepo',
      reviewedAt: DateTime(DateTime.now().year, 1, 15),
    ),
  ];

  @override
  Future<LicenseRenewal?> getActiveRenewal(String stallId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final stallRenewals = _renewals
        .where((r) => r.stallId == stallId || r.stallId == 'stall_mock_id' || stallId.isEmpty)
        .toList();

    if (stallRenewals.isEmpty) {
      final currentYear = DateTime.now().year;
      final defaultRenewal = LicenseRenewal(
        renewalId: 'ren-${stallId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}-$currentYear',
        stallId: stallId,
        vendorUid: stallId,
        vendorName: 'Stall License',
        periodStart: DateTime(currentYear, 1, 1),
        periodEnd: DateTime(currentYear, 12, 31, 23, 59, 59),
        amountPaid: 5000.0,
        paymentMethod: 'cash_at_office',
        status: LicenseRenewalStatus.approved,
        submittedAt: DateTime(currentYear, 1, 10),
        paidAt: DateTime(currentYear, 1, 12),
        reviewedBy: 'admin_mepo',
        reviewedAt: DateTime(currentYear, 1, 15),
      );
      _renewals.add(defaultRenewal);
      return defaultRenewal;
    }

    // Sort by periodEnd descending to get the latest
    final sorted = List<LicenseRenewal>.from(stallRenewals)
      ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));

    return sorted.first;
  }

  @override
  Future<List<LicenseRenewal>> getRenewalHistory(String stallId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var stallRenewals = _renewals
        .where((r) => r.stallId == stallId || r.stallId == 'stall_mock_id' || stallId.isEmpty)
        .toList();

    if (stallRenewals.isEmpty) {
      final active = await getActiveRenewal(stallId);
      if (active != null) stallRenewals = [active];
    }

    final sorted = List<LicenseRenewal>.from(stallRenewals)
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return sorted;
  }

  @override
  Future<LicenseRenewal> submitRenewal(LicenseRenewal renewal) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    final saved = LicenseRenewal(
      renewalId: 'mock-ren-${DateTime.now().millisecondsSinceEpoch}',
      stallId: renewal.stallId,
      vendorUid: renewal.vendorUid,
      vendorName: renewal.vendorName,
      periodStart: renewal.periodStart,
      periodEnd: renewal.periodEnd,
      amountPaid: renewal.amountPaid, // Hardcoded in UI for now
      paymentMethod: renewal.paymentMethod,
      submittedAt: DateTime.now(),
      status: LicenseRenewalStatus.pending,
    );

    _renewals.insert(0, saved);
    return saved;
  }

  @override
  Future<void> updateRenewalStatus(
    String renewalId,
    LicenseRenewalStatus status, {
    String? rejectionReason,
    String? reviewedBy,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _renewals.indexWhere((r) => r.renewalId == renewalId);
    if (index == -1) return;

    final current = _renewals[index];
    _renewals[index] = LicenseRenewal(
      renewalId: current.renewalId,
      stallId: current.stallId,
      vendorUid: current.vendorUid,
      vendorName: current.vendorName,
      periodStart: current.periodStart,
      periodEnd: current.periodEnd,
      amountPaid: current.amountPaid,
      paymentMethod: current.paymentMethod,
      paymentReferenceId: current.paymentReferenceId,
      submittedAt: current.submittedAt,
      status: status,
      paidAt: status == LicenseRenewalStatus.paid
          ? DateTime.now()
          : current.paidAt,
      reviewedBy: reviewedBy ?? current.reviewedBy,
      reviewedAt:
          (status == LicenseRenewalStatus.approved ||
              status == LicenseRenewalStatus.rejected)
          ? DateTime.now()
          : current.reviewedAt,
      rejectionReason: rejectionReason ?? current.rejectionReason,
    );
  }
}
