import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/features/vendors/domain/license_renewal.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';

class VendorLicenseStatusCard extends StatelessWidget {
  final LicenseStatus status;
  final LicenseRenewal? activeRenewal;
  final VendorStall stall;

  const VendorLicenseStatusCard({
    super.key,
    required this.status,
    this.activeRenewal,
    required this.stall,
  });

  @override
  Widget build(BuildContext context) {
    Color cardColor;
    Color iconColor;
    IconData icon;
    String statusText;

    switch (status) {
      case LicenseStatus.active:
        cardColor = const Color(0xFFF0FDF4);
        iconColor = AppTheme.statusOpen;
        icon = Icons.check_circle_rounded;
        statusText = 'Active';
        break;
      case LicenseStatus.expiringSoon:
        cardColor = const Color(0xFFFFFBEB);
        iconColor = const Color(0xFFF59E0B);
        icon = Icons.warning_rounded;
        statusText = 'Expiring Soon';
        break;
      case LicenseStatus.expired:
        cardColor = const Color(0xFFFEF2F2);
        iconColor = const Color(0xFFEF4444);
        icon = Icons.error_rounded;
        statusText = 'Expired';
        break;
      case LicenseStatus.suspended:
        cardColor = const Color(0xFF7F1D1D); // Dark Red
        iconColor = const Color(0xFFFECACA); // Light Red
        icon = Icons.block_rounded;
        statusText = 'Suspended';
        break;
      case LicenseStatus.pending:
        cardColor = const Color(0xFFFFFBEB);
        iconColor = const Color(0xFFF59E0B);
        icon = Icons.hourglass_empty_rounded;
        statusText = 'Pending Approval';
        break;
    }

    final now = DateTime.now();
    int daysLeft = 0;
    String expiryText = 'No active license';
    if (activeRenewal != null) {
      daysLeft = activeRenewal!.periodEnd.difference(now).inDays;
      expiryText = DateFormat('MMMM d, yyyy').format(activeRenewal!.periodEnd);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: status == LicenseStatus.suspended ? cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == LicenseStatus.suspended
              ? cardColor
              : AppTheme.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: status == LicenseStatus.suspended
                      ? const Color(0xFF991B1B)
                      : cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: status == LicenseStatus.suspended
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                  ),
                  if (activeRenewal != null &&
                      status == LicenseStatus.expiringSoon)
                    Text(
                      'Expires in $daysLeft days',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow(
            'Stall Name',
            stall.name,
            isDark: status == LicenseStatus.suspended,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Expiry Date',
            expiryText,
            isDark: status == LicenseStatus.suspended,
          ),

          if (activeRenewal != null && activeRenewal!.isPending)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.hourglass_empty_rounded,
                      color: Color(0xFFF59E0B),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Renewal request submitted. Awaiting MEPO approval.',
                        style: TextStyle(fontSize: 12, color: AppTheme.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isDark = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppTheme.surfaceContainerLow
                : AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
