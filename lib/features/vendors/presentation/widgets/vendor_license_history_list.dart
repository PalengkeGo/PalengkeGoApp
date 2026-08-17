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

        return Container(
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
}
