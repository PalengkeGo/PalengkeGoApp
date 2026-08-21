import 'dart:io';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/core/utils/image_picker_helper.dart';
import 'package:palengkego/core/infrastructure/supabase_storage_service.dart';
import 'package:palengkego/features/vendors/application/license_renewal_provider.dart';
import 'package:palengkego/features/vendors/domain/license_renewal.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';

/// Bottom sheet for submitting a license renewal: payment method,
/// optional document upload, and follow-up flag. Self-contained state.
class VendorLicenseRenewSheet extends ConsumerStatefulWidget {
  final VendorStall stall;

  const VendorLicenseRenewSheet({super.key, required this.stall});

  @override
  ConsumerState<VendorLicenseRenewSheet> createState() =>
      _VendorLicenseRenewSheetState();
}

class _VendorLicenseRenewSheetState
    extends ConsumerState<VendorLicenseRenewSheet> {
  final formatCurrency = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
  String _selectedPaymentMethod = 'paymongo_gcash';
  bool _hasUploadedDoc = false;
  bool _documentsToFollowUp = false;
  File? _docFile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Renew License',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your renewal will be valid for 1 year.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          // Fee summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Annual Fee',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  formatCurrency.format(5000), // Configurable in future
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Payment options
          _buildPaymentOption(
            id: 'paymongo_gcash',
            title: 'GCash (via PayMongo)',
            icon: Icons.account_balance_wallet_rounded,
            isSelected: _selectedPaymentMethod == 'paymongo_gcash',
            onTap: () =>
                setState(() => _selectedPaymentMethod = 'paymongo_gcash'),
          ),
          const SizedBox(height: 8),
          _buildPaymentOption(
            id: 'paymongo_paymaya',
            title: 'PayMaya (via PayMongo)',
            icon: Icons.account_balance_wallet_rounded,
            isSelected: _selectedPaymentMethod == 'paymongo_paymaya',
            onTap: () =>
                setState(() => _selectedPaymentMethod = 'paymongo_paymaya'),
          ),
          const SizedBox(height: 8),
          _buildPaymentOption(
            id: 'pay_in_person',
            title: 'Pay Personally / Pay in Person',
            icon: Icons.payments_rounded,
            isSelected: _selectedPaymentMethod == 'pay_in_person',
            onTap: () =>
                setState(() => _selectedPaymentMethod = 'pay_in_person'),
          ),
          const SizedBox(height: 20),

          // Documents Upload / Follow-up section
          const Text(
            'Renewal Documents',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final file = await ImagePickerHelper.pickImage(context);
              if (file != null) {
                setState(() {
                  _docFile = file;
                  _hasUploadedDoc = true;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasUploadedDoc
                        ? Icons.check_circle_rounded
                        : Icons.cloud_upload_outlined,
                    color: _hasUploadedDoc
                        ? AppTheme.primaryGreen
                        : AppTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _hasUploadedDoc
                          ? 'Document attached'
                          : 'Attach available documents',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _documentsToFollowUp,
                onChanged: (val) =>
                    setState(() => _documentsToFollowUp = val ?? false),
                activeColor: AppTheme.primaryGreen,
              ),
              const Expanded(
                child: Text(
                  'I don\'t have all documents yet (to follow up)',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action button
          ElevatedButton(
            onPressed: () {
              if (!_hasUploadedDoc && !_documentsToFollowUp) {
                showDialog(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Renewal Documents Required',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    content: const Text(
                      'Please attach at least one document or check "I don\'t have all documents yet" before proceeding.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
                return;
              }
              _processRenewal();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _selectedPaymentMethod == 'pay_in_person'
                  ? 'Request Renewal & Pay in Person'
                  : 'Pay & Renew',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.statusOpen : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.success : AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.success : AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.statusOpen,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _processRenewal() async {
    final stall = widget.stall;
    final now = DateTime.now();

    String? docUrl;
    final doc = _docFile;
    if (doc != null) {
      try {
        docUrl = await ref.read(supabaseStorageServiceProvider).uploadFile(
          bucket: SupabaseStorageService.licenseBucket,
          path:
              '${stall.ownerUid}/${SupabaseStorageService.objectName('renewal', doc)}',
          file: doc,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document upload failed: $e')),
        );
        return;
      }
    }

    final renewal = LicenseRenewal(
      renewalId: '', // Set by repo
      stallId: stall.stallId,
      vendorUid: stall.ownerUid,
      vendorName: stall.name,
      periodStart: now,
      periodEnd: now.add(const Duration(days: 365)),
      amountPaid: 5000.0,
      paymentMethod: _selectedPaymentMethod,
      documentUrl: docUrl,
      submittedAt: now,
      status: LicenseRenewalStatus.pending,
    );

    ref.read(licenseRenewalProcessorProvider.notifier).submitAndPay(renewal);

    if (!mounted) return;
    // Capture the messenger BEFORE popping — the sheet's context is
    // deactivated once the route closes.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _selectedPaymentMethod == 'pay_in_person'
              ? 'Payment Successful! Awaiting MEPO Approval.'
              : 'Renewal request submitted successfully.',
        ),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }
}
