import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/features/vendors/domain/license_renewal.dart';

class VendorLicenseHistoryList extends StatelessWidget {
  final List<LicenseRenewal> history;

  VendorLicenseHistoryList({super.key, required this.history});

  final formatCurrency = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const EmptyState(
        title: 'No renewal history found.',
        titleStyle: TextStyle(color: AppTheme.textSecondary),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: history.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final r = history[index];
        final start = DateFormat('MMM yyyy').format(r.periodStart);
        final end = DateFormat('MMM yyyy').format(r.periodEnd);

        return GestureDetector(
          onTap: () => _showRenewalDetails(context, r),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$start - $end',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency.format(r.amountPaid),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                _buildStatusChip(r.status),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(LicenseRenewalStatus status) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case LicenseRenewalStatus.pending:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF3B82F6);
        text = 'Pending';
        break;
      case LicenseRenewalStatus.paid:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFF59E0B);
        text = 'Paid';
        break;
      case LicenseRenewalStatus.approved:
        bg = const Color(0xFFF0FDF4);
        fg = AppTheme.statusOpen;
        text = 'Approved';
        break;
      case LicenseRenewalStatus.rejected:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFEF4444);
        text = 'Rejected';
        break;
      case LicenseRenewalStatus.expired:
        bg = AppTheme.surfaceContainerLow;
        fg = AppTheme.textSecondary;
        text = 'Expired';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  /// Detail popup for a single renewal: renewal date, approval date and the
  /// period the renewed license is valid for.
  void _showRenewalDetails(BuildContext context, LicenseRenewal r) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Renewal Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  _buildStatusChip(r.status),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                'Renewal date',
                DateFormat('MMM d, yyyy').format(r.submittedAt),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Approval date',
                _approvalDateLabel(r),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Valid for',
                _validityLabel(r),
                detail:
                    '${DateFormat('MMM d, yyyy').format(r.periodStart)} - '
                    '${DateFormat('MMM d, yyyy').format(r.periodEnd)}',
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Fee paid',
                formatCurrency.format(r.amountPaid),
                detail: _paymentLabel(r.paymentMethod),
              ),
              if (r.isRejected &&
                  r.rejectionReason != null &&
                  r.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Reason: ${r.rejectionReason}',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppTheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _approvalDateLabel(LicenseRenewal r) {
    if (r.reviewedAt != null) {
      return DateFormat('MMM d, yyyy').format(r.reviewedAt!);
    }
    if (r.isApproved || r.isRejected) return '-';
    return 'Awaiting review';
  }

  /// Human-friendly length of the renewed license period.
  String _validityLabel(LicenseRenewal r) {
    final days = r.periodEnd.difference(r.periodStart).inDays;
    final months = days ~/ 30;
    if (months >= 2) return '$months months';
    if (months == 1) return '1 month';
    return '$days days';
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'paymongo_gcash':
        return 'GCash (PayMongo)';
      case 'paymongo_paymaya':
        return 'PayMaya (PayMongo)';
      case 'paymongo_card':
        return 'Card (PayMongo)';
      case 'pay_in_person':
        return 'Pay in Person';
      case 'cash_at_office':
        return 'Cash at Office';
      default:
        return method;
    }
  }

  Widget _buildDetailRow(String label, String value, {String? detail}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.muted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 2),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
