import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/widgets/app_screen_header.dart';
import 'package:palengkego/features/checkout/domain/payment_selection.dart';

/// Payment Methods Screen
/// Allows user to select or add payment methods.
///
/// Supports:
/// - Cash on Delivery (default)
/// - GCash (via Paymongo)
/// - PayMaya (via Paymongo)
/// - Credit/Debit Card
class PaymentMethodsScreen extends StatefulWidget {
  final String? currentMethod;
  final String fulfillmentMethod;

  const PaymentMethodsScreen({
    super.key,
    this.currentMethod,
    this.fulfillmentMethod = 'delivery',
  });

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  String? _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.currentMethod ?? 'cod';
  }

  void _selectMethod(String method) {
    setState(() {
      _selectedMethod = method;
    });
    // Return selected method to previous screen
    Navigator.pop(context, PaymentSelectionResult(method: method));
  }

  Future<void> _addCard() async {
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.addCreditCard);
    if (result is CardSelectionData) {
      if (!mounted) return;
      setState(() {
        _selectedMethod = 'card';
      });
      Navigator.pop(
        context,
        PaymentSelectionResult(method: 'card', cardData: result),
      );
    }
  }

  /// Mock e-wallet account linking (GCash / PayMaya, both via Paymongo).
  Future<void> _linkEWallet({
    required String method,
    required String title,
    required Color brandColor,
  }) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Link $title Account',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mobile Number',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                  _PhoneSpaceFormatter(),
                ],
                decoration: appInputDecoration(
                  hintText: 'xxx xxx xxxx',
                  prefixText: '+63 ',
                  prefixStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                  fillColor: const Color(0xFFF3F4F6),
                  borderless: true,
                  focusedBorderWidth: 2,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(sheetContext); // Close bottom sheet

                    // Show loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => const AsyncLoadingView(),
                    );

                    // Simulate API delay
                    await Future.delayed(const Duration(seconds: 2));

                    if (!mounted) return;
                    Navigator.pop(context); // Close loading dialog

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$title account linked successfully!'),
                      ),
                    );

                    setState(() {
                      _selectedMethod = method;
                    });

                    Navigator.pop(
                      context,
                      PaymentSelectionResult(method: method),
                    );
                  },
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenHeader(
              title: 'Payment Methods',
              size: 32,
              titleSize: 18,
              onBack: () => Navigator.pop(context),
            ),

            // Payment options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Payment Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Cash on Delivery
                    _buildPaymentOption(
                      method: widget.fulfillmentMethod == 'pickup'
                          ? 'cop'
                          : 'cod',
                      title: widget.fulfillmentMethod == 'pickup'
                          ? 'Cash on Pickup'
                          : 'Cash on Delivery',
                      subtitle: widget.fulfillmentMethod == 'pickup'
                          ? 'Pay when you pick up your order'
                          : 'Pay when you receive your order',
                      icon: Icons.payments_outlined,
                      iconBgColor: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFF59E0B),
                      isSelected:
                          _selectedMethod == 'cod' || _selectedMethod == 'cop',
                      onTap: () => _selectMethod(
                        widget.fulfillmentMethod == 'pickup' ? 'cop' : 'cod',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // GCash
                    _buildPaymentOption(
                      method: 'gcash',
                      title: 'GCash',
                      subtitle: 'Pay with GCash via Paymongo',
                      brandIcon: SvgPicture.asset(
                        'assets/icons/gcash.svg',
                        fit: BoxFit.contain,
                        semanticsLabel: 'GCash',
                      ),
                      isSelected: _selectedMethod == 'gcash',
                      onTap: () => _linkEWallet(
                        method: 'gcash',
                        title: 'GCash',
                        brandColor: const Color(0xFF0079FF),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // PayMaya
                    _buildPaymentOption(
                      method: 'paymaya',
                      title: 'PayMaya',
                      subtitle: 'Pay with PayMaya via Paymongo',
                      brandIcon: Image.asset(
                        'assets/icons/paymaya.png',
                        fit: BoxFit.contain,
                        semanticLabel: 'PayMaya',
                      ),
                      isSelected: _selectedMethod == 'paymaya',
                      onTap: () => _linkEWallet(
                        method: 'paymaya',
                        title: 'PayMaya',
                        brandColor: const Color(0xFFED1C24),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Credit/Debit Card
                    _buildPaymentOption(
                      method: 'card',
                      title: 'Credit/Debit Card',
                      subtitle: 'Add a new card',
                      icon: Icons.credit_card_outlined,
                      iconBgColor: const Color(0xFF1A1F71),
                      iconColor: Colors.white,
                      isSelected: _selectedMethod == 'card',
                      onTap: _addCard,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String method,
    required String title,
    required String subtitle,
    Widget? brandIcon,
    IconData? icon,
    Color? iconBgColor,
    Color? iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: AppTheme.primaryGreen, width: 2)
              : null,
        ),
        child: Row(
          children: [
            if (brandIcon != null)
              // Brand marks render on a quiet white tile so the logo's own
              // colors carry the identity (GCash blue, PayMaya red).
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: brandIcon,
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhoneSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 10) text = text.substring(0, 10);
    var formatted = '';
    for (var i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) formatted += ' ';
      formatted += text[i];
    }

    int cursor = newValue.selection.baseOffset;
    if (cursor > formatted.length) {
      cursor = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
