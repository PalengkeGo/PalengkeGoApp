import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/features/vendors/application/license_renewal_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
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
  @override
  Widget build(BuildContext context) {
    final status = ref.watch(computedLicenseStatusProvider);
    final activeRenewalAsync = ref.watch(activeRenewalProvider);
    final historyAsync = ref.watch(renewalHistoryProvider);
    final stall = ref.watch(vendorStallProvider);

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
