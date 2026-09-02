import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palengkego/core/widgets/app_screen_header.dart';
import 'package:palengkego/features/checkout/domain/payment_selection.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';

/// Payment Methods Screen
/// Allows user to check in, connect, disconnect, and select payment methods.
///
/// Supports:
/// - Cash on Delivery / Cash on Pickup
/// - GCash (via Paymongo)
/// - PayMaya (via Paymongo)
/// - Credit/Debit Card
class PaymentMethodsScreen extends ConsumerStatefulWidget {
  final String? currentMethod;
  final String fulfillmentMethod;
  final bool isManageMode;

  const PaymentMethodsScreen({
    super.key,
    this.currentMethod,
    this.fulfillmentMethod = 'delivery',
    this.isManageMode = false,
  });

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  String? _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.currentMethod ?? 'cod';
  }

  void _selectMethod(String method, {String? cardLabel}) {
    setState(() {
      _selectedMethod = method;
    });

    ref
        .read(preferencesProvider.notifier)
        .updatePaymentMethod(method, cardLabel: cardLabel);

    if (widget.isManageMode) {
      final methodTitle = switch (method) {
        'gcash' => 'GCash',
        'paymaya' => 'PayMaya',
        'card' => cardLabel ?? 'Credit/Debit Card',
        'cop' => 'Cash on Pickup',
        _ => 'Cash on Delivery',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Default payment method set to $methodTitle'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Return selected method to checkout
      Navigator.pop(
        context,
        PaymentSelectionResult(
          method: method,
          cardData: cardLabel != null
              ? CardSelectionData(
                  last4: cardLabel.replaceAll(RegExp(r'\D'), ''),
                  brand: 'Card',
                  expiry: '12/28',
                  cardholderName: 'Cardholder',
                )
              : null,
        ),
      );
    }
  }

  /// Show modal to link e-wallet account (GCash / PayMaya).
  Future<void> _linkEWallet({
    required String method,
    required String title,
    required Color brandColor,
  }) async {
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
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
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Connect $title Account',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.muted),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Link your $title mobile number to enable seamless one-tap payments via PayMongo.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Mobile Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                    _PhoneSpaceFormatter(),
                  ],
                  validator: (val) {
                    final digits =
                        (val ?? '').replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 10) {
                      return 'Please enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                  decoration: appInputDecoration(
                    hintText: '9xx xxx xxxx',
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
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final rawDigits = phoneController.text.replaceAll(
                        RegExp(r'\D'),
                        '',
                      );
                      final formatted =
                          '+63 ${rawDigits.substring(0, 3)} ${rawDigits.substring(3, 6)} ${rawDigits.substring(6)}';

                      Navigator.pop(sheetContext); // Close sheet

                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (dialogContext) =>
                            const AsyncLoadingView(),
                      );

                      // Simulate secure PayMongo handshake
                      await Future.delayed(const Duration(seconds: 1));

                      if (!mounted) return;
                      Navigator.pop(context); // Close loading dialog

                      ref
                          .read(preferencesProvider.notifier)
                          .connectPaymentAccount(method, formatted);

                      setState(() {
                        _selectedMethod = method;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '$title account connected successfully!',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );

                      if (!widget.isManageMode) {
                        Navigator.pop(
                          context,
                          PaymentSelectionResult(method: method),
                        );
                      }
                    },
                    child: Text(
                      'Connect $title',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show disconnect confirmation dialog.
  Future<void> _confirmDisconnect({
    required String method,
    required String title,
    required String? accountDetail,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Disconnect $title?',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to unlink your $title account${accountDetail != null ? " ($accountDetail)" : ""}? You can reconnect it at any time.',
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text(
              'Disconnect',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ref.read(preferencesProvider.notifier).disconnectPaymentAccount(method);
      setState(() {
        if (_selectedMethod == method) {
          _selectedMethod = 'cod';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title account disconnected'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsState = ref.watch(preferencesProvider);
    final isGCashConnected =
        prefsState.isPaymentMethodConnected('gcash');
    final gcashAccount = prefsState.getPaymentMethodAccount('gcash');

    final isMayaConnected =
        prefsState.isPaymentMethodConnected('paymaya');
    final mayaAccount = prefsState.getPaymentMethodAccount('paymaya');

    final codMethod =
        widget.fulfillmentMethod == 'pickup' ? 'cop' : 'cod';
    final codTitle = widget.fulfillmentMethod == 'pickup'
        ? 'Cash on Pickup'
        : 'Cash on Delivery';
    final codSubtitle = widget.fulfillmentMethod == 'pickup'
        ? 'Pay in cash when picking up your order'
        : 'Pay in cash upon doorstep delivery';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenHeader(
              title: widget.isManageMode
                  ? 'Payment Methods'
                  : 'Select Payment Method',
              size: 32,
              titleSize: 18,
              onBack: () => Navigator.pop(context),
            ),

            // Payment Options List
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isManageMode
                          ? 'Connected Payment Options'
                          : 'Choose Payment Option',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.isManageMode
                          ? 'Connect or disconnect your digital wallets and cards to easily manage checkout options.'
                          : 'Select an available payment method or connect a digital wallet.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Cash on Delivery / Cash on Pickup ─────────────
                    _buildPaymentMethodTile(
                      method: codMethod,
                      title: codTitle,
                      subtitle: codSubtitle,
                      icon: Icons.payments_outlined,
                      iconBgColor: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFF59E0B),
                      isConnected: true,
                      isSelected: _selectedMethod == codMethod ||
                          _selectedMethod == 'cod' ||
                          _selectedMethod == 'cop',
                      onTap: () => _selectMethod(codMethod),
                    ),
                    const SizedBox(height: 14),

                    // ── GCash ─────────────────────────────────────────
                    _buildPaymentMethodTile(
                      method: 'gcash',
                      title: 'GCash',
                      subtitle: isGCashConnected
                          ? (gcashAccount ?? 'Connected via PayMongo')
                          : 'Link your GCash wallet via PayMongo',
                      brandIcon: SvgPicture.asset(
                        'assets/icons/gcash.svg',
                        fit: BoxFit.contain,
                        semanticsLabel: 'GCash',
                      ),
                      isConnected: isGCashConnected,
                      isSelected: _selectedMethod == 'gcash',
                      onConnect: () => _linkEWallet(
                        method: 'gcash',
                        title: 'GCash',
                        brandColor: const Color(0xFF0079FF),
                      ),
                      onDisconnect: () => _confirmDisconnect(
                        method: 'gcash',
                        title: 'GCash',
                        accountDetail: gcashAccount,
                      ),
                      onTap: () {
                        if (isGCashConnected) {
                          _selectMethod('gcash');
                        } else {
                          _linkEWallet(
                            method: 'gcash',
                            title: 'GCash',
                            brandColor: const Color(0xFF0079FF),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── PayMaya ───────────────────────────────────────
                    _buildPaymentMethodTile(
                      method: 'paymaya',
                      title: 'PayMaya',
                      subtitle: isMayaConnected
                          ? (mayaAccount ?? 'Connected via PayMongo')
                          : 'Link your Maya wallet via PayMongo',
                      brandIcon: Image.asset(
                        'assets/icons/paymaya.png',
                        fit: BoxFit.contain,
                        semanticLabel: 'PayMaya',
                      ),
                      isConnected: isMayaConnected,
                      isSelected: _selectedMethod == 'paymaya',
                      onConnect: () => _linkEWallet(
                        method: 'paymaya',
                        title: 'PayMaya',
                        brandColor: const Color(0xFFED1C24),
                      ),
                      onDisconnect: () => _confirmDisconnect(
                        method: 'paymaya',
                        title: 'PayMaya',
                        accountDetail: mayaAccount,
                      ),
                      onTap: () {
                        if (isMayaConnected) {
                          _selectMethod('paymaya');
                        } else {
                          _linkEWallet(
                            method: 'paymaya',
                            title: 'PayMaya',
                            brandColor: const Color(0xFFED1C24),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── Credit / Debit Card ───────────────────────────
                    _buildPaymentMethodTile(
                      method: 'card',
                      title: 'Credit / Debit Card',
                      subtitle: 'Visa, Mastercard, or JCB cards',
                      icon: Icons.credit_card_outlined,
                      iconBgColor: const Color(0xFF1A1F71),
                      iconColor: Colors.white,
                      isConnected: false,
                      isSelected: false,
                      isComingSoon: true,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Credit / Debit Card payment coming soon!',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
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

  Widget _buildPaymentMethodTile({
    required String method,
    required String title,
    required String subtitle,
    Widget? brandIcon,
    IconData? icon,
    Color? iconBgColor,
    Color? iconColor,
    required bool isConnected,
    required bool isSelected,
    bool isComingSoon = false,
    VoidCallback? onConnect,
    VoidCallback? onDisconnect,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0FDF4) : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.primaryGreen : AppTheme.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    if (brandIcon != null)
                      Container(
                        width: 46,
                        height: 46,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: brandIcon,
                      )
                    else
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, size: 24, color: iconColor),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(
                                isConnected: isConnected,
                                isComingSoon: isComingSoon,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isConnected &&
                                      (method != 'cod' && method != 'cop')
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isConnected &&
                                      (method != 'cod' && method != 'cop')
                                  ? AppTheme.primaryGreen
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isComingSoon)
                      const SizedBox.shrink()
                    else if (isSelected)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 15,
                          color: Colors.white,
                        ),
                      )
                    else
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 2,
                          ),
                        ),
                      ),
                  ],
                ),
                if (method != 'cod' && method != 'cop') ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: AppTheme.surfaceContainerLow),
                  const SizedBox(height: 10),
                  if (isComingSoon)
                    const Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppTheme.muted,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Card payments integration coming soon',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isConnected ? 'Status: Active' : 'Status: Not Connected',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isConnected
                                ? AppTheme.primaryGreen
                                : AppTheme.muted,
                          ),
                        ),
                        if (isConnected)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: const Color(0xFFEF4444),
                            ),
                            icon: const Icon(
                              Icons.link_off_rounded,
                              size: 14,
                            ),
                            label: const Text(
                              'Disconnect',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: onDisconnect,
                          )
                        else
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: AppTheme.primaryGreen,
                            ),
                            icon: const Icon(
                              Icons.link_rounded,
                              size: 14,
                            ),
                            label: const Text(
                              'Connect',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: onConnect,
                          ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool isConnected,
    bool isComingSoon = false,
  }) {
    if (isComingSoon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Text(
          'Coming Soon',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFB45309),
          ),
        ),
      );
    }
    if (isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: const Text(
          'Connected',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF15803D),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Text(
        'Not Linked',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
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
