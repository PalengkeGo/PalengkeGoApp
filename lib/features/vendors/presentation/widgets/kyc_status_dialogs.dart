import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_onboarding_screen.dart';

/// Popup dialog shown to vendors whose KYC application was rejected by MEPO.
///
/// Features a prominent reason box and a direct "Resubmit Documents" action.
class KycRejectionDialog extends StatelessWidget {
  final String? rejectionReason;
  final VoidCallback? onResubmit;

  const KycRejectionDialog({
    super.key,
    this.rejectionReason,
    this.onResubmit,
  });

  static Future<void> show(
    BuildContext context, {
    String? rejectionReason,
    VoidCallback? onResubmit,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => KycRejectionDialog(
        rejectionReason: rejectionReason,
        onResubmit: onResubmit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reason = (rejectionReason != null && rejectionReason!.trim().isNotEmpty)
        ? rejectionReason!.trim()
        : 'Incomplete or unreadable permit documents provided.';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_late_rounded,
              color: Color(0xFFDC2626),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Application Rejected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your stall holder application was reviewed by Market Administration (MEPO) and was not approved.',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REASON FROM MEPO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7F1D1D),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Please update your documents according to the remarks above and resubmit for review.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Dismiss',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            if (onResubmit != null) {
              onResubmit!();
            } else {
              Navigator.of(context).push(
                PageTransitions.slideFromRight(
                  const VendorOnboardingScreen(),
                ),
              );
            }
          },
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text(
            'Resubmit Documents',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog shown when a vendor's application is pending review by MEPO.
class KycPendingDialog extends StatelessWidget {
  final DateTime? submittedAt;

  const KycPendingDialog({
    super.key,
    this.submittedAt,
  });

  static Future<void> show(BuildContext context, {DateTime? submittedAt}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => KycPendingDialog(submittedAt: submittedAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = submittedAt != null
        ? DateFormat('MMMM d, yyyy h:mm a').format(submittedAt!)
        : null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: Color(0xFFD97706),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Approval Pending',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your stall holder application and KYC documents have been submitted and are currently under review by the Market Operations Office (MEPO).',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
          if (dateStr != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Submitted: $dateStr',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Verification typically takes 1–3 business days. You will receive an in-app alert as soon as MEPO processes your application.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}
