import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/features/vendors/application/vendor_complaint_service.dart';

class FlagVendorBottomSheet extends ConsumerStatefulWidget {
  final String vendorName;
  final String stallId;

  const FlagVendorBottomSheet({
    super.key,
    required this.vendorName,
    required this.stallId,
  });

  static Future<void> show(
    BuildContext context, {
    required String vendorName,
    required String stallId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.6),
      builder: (context) => FlagVendorBottomSheet(
        vendorName: vendorName,
        stallId: stallId,
      ),
    );
  }

  @override
  ConsumerState<FlagVendorBottomSheet> createState() =>
      _FlagVendorBottomSheetState();
}

class _FlagVendorBottomSheetState
    extends ConsumerState<FlagVendorBottomSheet> {
  final List<String> _reasons = [
    'Inappropriate Content',
    'Scam or Fraud',
    'Harassment or Abuse',
    'Fake Items / Counterfeits',
    'Other',
  ];

  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _submitting = false;

  Future<void> _submitReport() async {
    final reason = _selectedReason;
    if (reason == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await submitVendorComplaint(
        ref,
        stallId: widget.stallId,
        reason: reason,
        details: _detailsController.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      AppServices.showSnackBar('Report submitted for ${widget.vendorName}.');
    } catch (error, stackTrace) {
      debugPrint('Vendor report submission failed: $error\n$stackTrace');
      AppServices.showError('Could not submit the report. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Report Stall Holder',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Why are you reporting ${widget.vendorName}?',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ..._reasons.map((reason) {
                final isSelected = _selectedReason == reason;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedReason = reason;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF0FDF4)
                          : Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFE5E7EB),
                        width: isSelected ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.success
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                decoration: appInputDecoration(
                  hintText: 'Add any additional details (optional)',
                  hintStyle: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 14,
                  ),
                  fillColor: const Color(0xFFF9FAFB),
                  borderColor: const Color(0xFFE5E7EB),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedReason == null || _submitting
                      ? null
                      : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: AppTheme.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Submit Report',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
