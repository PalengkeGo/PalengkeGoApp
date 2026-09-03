import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/features/vendors/application/license_renewal_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/domain/license_renewal.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';
import 'package:palengkego/features/vendors/presentation/widgets/vendor_screen_header.dart';
import '../widgets/vendor_license_history_list.dart';
import '../widgets/vendor_license_renew_sheet.dart';
import '../widgets/vendor_license_status_card.dart';

class VendorLicenseScreen extends ConsumerStatefulWidget {
  const VendorLicenseScreen({super.key});

  @override
  ConsumerState<VendorLicenseScreen> createState() =>
      _VendorLicenseScreenState();
}

class _VendorLicenseScreenState extends ConsumerState<VendorLicenseScreen> {
  /// Ensures the success overlay is shown at most once per approval.
  bool _approvalOverlayShown = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(computedLicenseStatusProvider);
    final activeRenewalAsync = ref.watch(activeRenewalProvider);
    final historyAsync = ref.watch(renewalHistoryProvider);
    final stall = ref.watch(vendorStallProvider);

    // Celebration: the moment the vendor's active renewal becomes approved —
    // either live (transition pending/paid -> approved while this screen is
    // open) or a fresh approval seen when the screen loads (e.g. the app was
    // backgrounded while MEPO approved it).
    ref.listen<AsyncValue<LicenseRenewal?>>(activeRenewalProvider,
        (previous, next) {
      final current = next.value;
      if (current == null ||
          !current.isApproved ||
          _approvalOverlayShown) {
        return;
      }
      final prevRenewal = previous?.value;
      final liveTransition = prevRenewal != null &&
          prevRenewal.renewalId == current.renewalId &&
          prevRenewal.status != LicenseRenewalStatus.approved;
      final freshApproval = prevRenewal == null &&
          current.reviewedAt != null &&
          DateTime.now().difference(current.reviewedAt!) <
              const Duration(minutes: 10);
      if (!liveTransition && !freshApproval) return;
      _approvalOverlayShown = true;
      // Short delay so the refreshed screen settles under the overlay.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showRenewalApprovedOverlay(current);
        }
      });
    });

    return AuthGuard(
      allowedRoles: {UserRole.vendor},
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              const VendorScreenHeader(title: 'Stall License'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      activeRenewalAsync.when(
                        data: (activeRenewal) => VendorLicenseStatusCard(
                          status: status,
                          activeRenewal: activeRenewal,
                          stall: stall,
                        ),
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        error: (err, _) => Text('Error: $err'),
                      ),
                      const SizedBox(height: 32),

                      const Text(
                        'Renewal History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      historyAsync.when(
                        data: (history) =>
                            VendorLicenseHistoryList(history: history),
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        error: (err, _) => Text('Error: $err'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar:
            (status == LicenseStatus.expiringSoon ||
                status == LicenseStatus.expired ||
                status == LicenseStatus.suspended)
            ? _buildRenewBottomBar(stall)
            : null,
      ),
    );
  }

  void _showRenewalApprovedOverlay(LicenseRenewal renewal) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RenewalApprovedOverlay(renewal: renewal),
      ),
    );
  }

  Widget _buildRenewBottomBar(VendorStall stall) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.white,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (ctx) => VendorLicenseRenewSheet(stall: stall),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Renew License',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen white success overlay (GCash/PayMaya-style "success" screen)
/// shown when the vendor's license renewal is approved.
class _RenewalApprovedOverlay extends StatelessWidget {
  final LicenseRenewal renewal;

  const _RenewalApprovedOverlay({required this.renewal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                size: 104,
                color: AppTheme.statusOpen,
              ),
              const SizedBox(height: 24),
              const Text(
                'Renewal Approved',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Congratulations! Your stall license renewal has been '
                'approved by MEPO. Your license is now active.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Valid until ${DateFormat('MMMM d, yyyy').format(renewal.periodEnd)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 15,
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
}
