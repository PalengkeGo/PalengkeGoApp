import 'package:palengkego/features/vendors/domain/license_renewal.dart';
import 'package:palengkego/features/vendors/domain/license_renewal_repository.dart';

class MockLicenseRenewalRepository implements LicenseRenewalRepository {
  /// We seed the mock with one "approved" renewal that expires in 30 days.
  /// This lets the vendor test the "Expiring Soon" flow immediately.
  final List<LicenseRenewal> _renewals = [
    LicenseRenewal(
      renewalId: 'mock-ren-seed',
      stallId: 'stall_mock_id',
      vendorUid: 'mock_uid',
      vendorName: 'Mock Stall',
      periodStart: DateTime.now().subtract(const Duration(days: 335)),
      periodEnd: DateTime.now().add(
        const Duration(days: 30),
      ), // Expires in 30 days
      amountPaid: 5000.0,
      paymentMethod: 'cash_at_office',
      status: LicenseRenewalStatus.approved,
      submittedAt: DateTime.now().subtract(const Duration(days: 340)),
      paidAt: DateTime.now().subtract(const Duration(days: 338)),
      reviewedBy: 'admin_123',
      reviewedAt: DateTime.now().subtract(const Duration(days: 335)),
    ),
  ];

  @override
  Future<LicenseRenewal?> getActiveRenewal(String stallId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_renewals.isEmpty) return null;

    // Sort by periodEnd descending to get the latest
    final sorted = List<LicenseRenewal>.from(_renewals)
      ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));

    return sorted.first;
  }

  @override
  Future<List<LicenseRenewal>> getRenewalHistory(String stallId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final sorted = List<LicenseRenewal>.from(_renewals)
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
