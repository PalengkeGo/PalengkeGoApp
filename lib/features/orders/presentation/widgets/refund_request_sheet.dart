import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';

/// Common reasons a customer picks when requesting a refund. Quick selections
/// keep the flow fast on mobile; "Other" plus the free-text note covers the rest.
const List<String> kRefundReasons = [
  'Order never arrived',
  'Item missing from order',
  'Item not fresh or damaged',
  'Wrong item received',
  'Charged incorrectly',
  'Other',
];

/// Bottom sheet a customer uses to request a refund on a paid order.
///
/// This is an Operate surface: the task (state the problem, confirm the
/// request) must stay crystal clear. No money moves here — the sheet owns the
/// customer's intent; a vendor or admin approves it separately.
/// Returns `true` after a successful request.
Future<bool?> showRefundRequestSheet(
  BuildContext context,
  MarketOrder order,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Keep a large top radius on the light sheet, matching the app's sheets.
    builder: (sheetContext) => _RefundRequestSheet(order: order),
  );
}

class _RefundRequestSheet extends ConsumerStatefulWidget {
  const _RefundRequestSheet({required this.order});

  final MarketOrder order;

  @override
  ConsumerState<_RefundRequestSheet> createState() => _RefundRequestSheetState();
}

class _RefundRequestSheetState extends ConsumerState<_RefundRequestSheet> {
  final _noteController = TextEditingController();
  String? _selectedReason;
  bool _submitting = false;
  String? _noteError;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason for your refund.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    _noteError = null;
    try {
      final note = _noteController.text.trim();
      final combined =
          note.isEmpty ? reason : (reason == 'Other' ? note : '$reason — $note');
      await ref
          .read(orderServiceProvider.notifier)
          .requestRefund(widget.order.id, reason: combined);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on OrderFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _noteError = e.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final refundable = order.total - order.refundedAmount;
    final mq = MediaQuery.of(context);

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        // Raise the sheet above the on-screen keyboard.
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: mq.viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle, centered.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title + clarifying subline.
              const Text(
                'Request a refund',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'The stall holder reviews your request and the refund '
                'returns to your original payment method.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              // Refundable amount context.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.scaffoldBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'REFUNDABLE AMOUNT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: AppTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatPeso(refundable),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (order.refundedAmount > 0)
                      const Text(
                        'Some already returned',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.success,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'What went wrong?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _ReasonChips(
                options: kRefundReasons,
                selected: _selectedReason,
                onSelected: (r) => setState(() => _selectedReason = r),
              ),

              const SizedBox(height: 20),

              const Text(
                'Add a note (optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: _noteController,
                maxLines: 3,
                hintText:
                    'For example: the kangkong was wilted and missing stems.',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.muted,
                  height: 1.4,
                ),
                fillColor: AppTheme.scaffoldBackground,
                borderRadius: 12,
                contentPadding: const EdgeInsets.all(14),
                errorText: _noteError,
                errorBorderColor: AppTheme.error,
              ),

              const SizedBox(height: 24),

              // Primary action. Trailing arrow sits inside its own circle, a
              // small confident detail within the system's button vocabulary.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Request refund'),
                            const SizedBox(width: 10),
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: Colors.white12,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPeso(double value) =>
      '₱${value.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';
}

/// Single-select wrap of reason options. Selected is unmistakable via fill +
/// weight + check, not color alone.
class _ReasonChips extends StatelessWidget {
  const _ReasonChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((r) {
        final isSelected = r == selected;
        return InkWell(
          onTap: () => onSelected(r),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryGreen : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryGreen
                    : AppTheme.surfaceContainer,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.textPrimary,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check, size: 14, color: Colors.white),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}