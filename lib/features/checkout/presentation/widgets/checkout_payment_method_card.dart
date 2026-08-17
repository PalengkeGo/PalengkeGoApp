import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/navigation/app_router.dart';
import 'package:palengkego/features/checkout/domain/payment_selection.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';

/// Tappable card showing the selected payment method; opens the
/// payment-methods picker on tap.
class CheckoutPaymentMethodCard extends ConsumerWidget {
  final int deliveryMethod;

  const CheckoutPaymentMethodCard({super.key, required this.deliveryMethod});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).pushNamed(
          AppRoutes.paymentMethods,
          arguments: PaymentMethodsRouteArgs(
            currentMethod: ref.read(preferencesProvider).paymentMethod,
            fulfillmentMethod: deliveryMethod == 0 ? 'delivery' : 'pickup',
          ),
        );
        if (!context.mounted) return;
        if (result is PaymentSelectionResult) {
          final method = result.method;
          final cardLabel = result.cardData?.displayLabel;
          ref
              .read(preferencesProvider.notifier)
              .updatePaymentMethod(method, cardLabel: cardLabel);
          final message = switch (method) {
            'cod' => AppLocalizations.of(context).codSelected,
            'gcash' => AppLocalizations.of(context).gcashSelected,
            'card' => AppLocalizations.of(context).cardSelected,
            _ => AppLocalizations.of(context).paymentMethodUpdated,
          };
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.payments_outlined,
                  size: 20,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.watch(preferencesProvider).paymentTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ref.watch(preferencesProvider).paymentSubtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}
