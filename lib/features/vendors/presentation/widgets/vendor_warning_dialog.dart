import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal dialog presented to a vendor upon opening the app when an official
/// warning has been issued by Market Administration (MEPO).
class VendorWarningDialog extends ConsumerWidget {
  final AppNotification warning;
  final VoidCallback onAcknowledge;

  const VendorWarningDialog({
    super.key,
    required this.warning,
    required this.onAcknowledge,
  });

  /// Displays the warning dialog modally. Forces active acknowledgment.
  static Future<void> show(
    BuildContext context, {
    required AppNotification warning,
    required VoidCallback onAcknowledge,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          VendorWarningDialog(warning: warning, onAcknowledge: onAcknowledge),
    );
  }

  Future<void> _editProduct(BuildContext context, WidgetRef ref) async {
    final productId = warning.referenceId;
    if (productId == null || productId.isEmpty) {
      return;
    }
    final vendorId =
        ref.read(currentVendorIdProvider) ??
        ref.read(vendorStallProvider).stallId;
    try {
      ref.invalidate(vendorProductsProvider(vendorId));
      final products = await ref.read(vendorProductsProvider(vendorId).future);
      final product = products
          .where((item) => item.id == productId)
          .firstOrNull;
      if (product == null) {
        throw StateError('The flagged product could not be found.');
      }
      onAcknowledge();
      if (!context.mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushNamed(
        AppRoutes.vendorAddProduct,
        arguments: VendorAddProductRouteArgs(existingProduct: product),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open this product: $error')),
      );
    }
  }

  Future<void> _openMepoPost(BuildContext context) async {
    final uri = warning.mepoPricePostUri;
    if (uri == null) return;
    onAcknowledge();
    Navigator.of(context).pop();
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the MEPO Facebook post.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the MEPO Facebook post.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProduct = warning.referenceId?.isNotEmpty == true;
    final mepoPost = warning.mepoPricePostUri;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning Icon Header
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFDE68A), width: 3),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 38,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tag Pill
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Text(
                  'MEPO • OFFICIAL DISCIPLINARY NOTICE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Dialog Title
            const Text(
              'Administrative Warning',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              warning.title.isNotEmpty
                  ? warning.title
                  : 'Market Compliance Notice',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Warning Notice Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.report_problem_outlined,
                        size: 16,
                        color: Color(0xFFB45309),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Reason & Directive from Administration:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    warning.displayBody,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF78350F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Market Policy Sanction Notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All stall holders are required to maintain palengke quality standards. Repeat violations may result in temporary stall suspension or lease revocation.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (hasProduct)
              OutlinedButton.icon(
                onPressed: () => _editProduct(context, ref),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit flagged product'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  side: const BorderSide(color: AppTheme.primaryGreen),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            if (mepoPost != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _openMepoPost(context),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('View MEPO weekly price post'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1877F2),
                  side: const BorderSide(color: Color(0xFF1877F2)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),

            // Acknowledge Button
            ElevatedButton(
              onPressed: () {
                onAcknowledge();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'I Understand & Acknowledge',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
