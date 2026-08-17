import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/checkout/application/checkout_controller.dart';

import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';
import 'package:palengkego/core/widgets/app_screen_header.dart';
import 'package:palengkego/core/navigation/app_router.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/features/checkout/presentation/widgets/checkout_delivery_cards.dart';
import 'package:palengkego/features/checkout/presentation/widgets/checkout_delivery_option_card.dart';
import 'package:palengkego/features/checkout/presentation/widgets/checkout_footer.dart';
import 'package:palengkego/features/checkout/presentation/widgets/checkout_method_toggle.dart';
import 'package:palengkego/features/checkout/presentation/widgets/checkout_order_item.dart';
import 'package:palengkego/features/checkout/presentation/widgets/checkout_pickup_cards.dart';
import 'package:palengkego/features/checkout/presentation/widgets/checkout_section_title.dart';
import 'package:palengkego/features/checkout/presentation/widgets/checkout_summary_row.dart';
import 'package:palengkego/features/checkout/presentation/widgets/checkout_payment_method_card.dart';
import 'package:palengkego/features/checkout/presentation/widgets/checkout_vendor_notes.dart';
import 'package:palengkego/features/checkout/presentation/widgets/checkout_place_order_dialog.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(cartItemsProvider);
    final items = itemsAsync.value ?? [];
    final preferences = ref.watch(preferencesProvider);
    final selectedItems = items.where((item) => item.selected).toList();
    final subtotal = selectedItems.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );

    final Map<String, List<CartItem>> itemsByVendor = {};
    for (final item in selectedItems) {
      itemsByVendor.putIfAbsent(item.vendorName, () => []);
      itemsByVendor[item.vendorName]!.add(item);
    }

    final deliveryAddress = preferences.deliveryAddress;

    final checkout = ref.watch(checkoutProvider);
    final deliveryMethod = checkout.deliveryMethod;
    final deliveryFee = deliveryMethod == 0 ? FeeConfig.deliveryFee : 0.0;
    final priorityFee = checkout.priorityFee;

    return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                AppScreenHeader(
                  title: AppLocalizations.of(context).checkoutSectionTitle,
                  size: 32,
                  titleSize: 18,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckoutMethodToggle(
                          deliveryMethod: deliveryMethod,
                          onChanged: (value) {
                            ref
                                .read(checkoutProvider.notifier)
                                .setDeliveryMethod(value);
                            ref
                                .read(preferencesProvider.notifier)
                                .updatePaymentMethod(
                                  value == 0 ? 'cod' : 'cop',
                                );
                          },
                        ),
                        const SizedBox(height: 24),
                        if (deliveryMethod == 0) ...[
                          CheckoutSectionTitle(
                            icon: Icons.location_on_outlined,
                            title: AppLocalizations.of(
                              context,
                            ).deliveryAddressTitle,
                          ),
                          const SizedBox(height: 12),
                          CheckoutDeliveryAddressCard(
                            deliveryAddress: deliveryAddress,
                            onChange: () async {
                              final result = await Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.setDeliveryAddress);
                              if (!mounted) return;
                              if (result is DeliveryAddress) {
                                ref
                                    .read(preferencesProvider.notifier)
                                    .updateAddress(
                                      primaryAddress:
                                          result.primaryAddress.isEmpty
                                          ? deliveryAddress.primaryAddress
                                          : result.primaryAddress,
                                      streetAddress: result.streetAddress,
                                      notes: result.notes,
                                    );
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          CheckoutDeliveryOptionCard(
                            isPrioritySelected: checkout.isPriority,
                            onOptionChanged: (val) {
                              ref
                                  .read(checkoutProvider.notifier)
                                  .setPriority(val);
                            },
                          ),
                        ] else ...[
                          const CheckoutPickupHeader(),
                          const SizedBox(height: 12),
                          ...itemsByVendor.entries.map((entry) {
                            final vendorName = entry.key;
                            final allVendors = ref
                                .watch(allVendorsProvider)
                                .maybeWhen(data: (v) => v, orElse: () => []);
                            final vendorModel = allVendors.firstWhere(
                              (v) => v.name == vendorName,
                              orElse: () => const MarketVendor(
                                id: '',
                                name: 'Stall Holder',
                                category: 'General',
                                rating: 4.6,
                                isVerified: false,
                                distance: '',
                                imageUrl: '',
                                stallNumber: 'Market Stall',
                                marketSection: 'Fish Section',
                              ),
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: CheckoutPickupCard(
                                vendorName: vendorName,
                                vendorStall:
                                    vendorModel.stallNumber ?? 'Market Stall',
                                vendorSection:
                                    vendorModel.marketSection ?? 'Fish Section',
                                vendorRating: vendorModel.rating,
                                vendorCount: 1,
                                vendorImageUrl: vendorModel.imageUrl,
                              ),
                            );
                          }),
                          const CheckoutReadyTimeCard(),
                        ],
                        const SizedBox(height: 24),
                        CheckoutSectionTitle(
                          icon: Icons.credit_card_outlined,
                          title: AppLocalizations.of(
                            context,
                          ).paymentMethodTitle,
                        ),
                        const SizedBox(height: 12),
                        CheckoutPaymentMethodCard(
                          deliveryMethod: deliveryMethod,
                        ),
                        const SizedBox(height: 24),
                        CheckoutSectionTitle(
                          icon: Icons.shopping_basket_outlined,
                          title: AppLocalizations.of(context).orderSummaryTitle,
                        ),
                        const SizedBox(height: 12),
                        ...selectedItems.map(
                          (item) => CheckoutOrderItem(item: item),
                        ),
                        const SizedBox(height: 24),
                        CheckoutSectionTitle(
                          icon: Icons.note_alt_outlined,
                          title: AppLocalizations.of(context).orderNotesTitle,
                        ),
                        const SizedBox(height: 12),
                        ...itemsByVendor.keys.map((vendorName) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: CheckoutVendorNotes(
                              vendorName: vendorName,
                              controller: ref
                                  .read(checkoutProvider.notifier)
                                  .notesControllerFor(vendorName),
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                        const Divider(color: AppTheme.border),
                        const SizedBox(height: 12),
                        CheckoutSummaryRow(
                          label: AppLocalizations.of(context).summarySubtotal,
                          value: '₱${subtotal.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 8),
                        CheckoutSummaryRow(
                          label: AppLocalizations.of(
                            context,
                          ).summaryDeliveryFee,
                          value: deliveryMethod == 0
                              ? '₱${deliveryFee.toStringAsFixed(2)}'
                              : AppLocalizations.of(context).feeFree,
                          highlighted: deliveryMethod == 1,
                        ),
                        if (deliveryMethod == 0 && checkout.isPriority) ...[
                          const SizedBox(height: 8),
                          CheckoutSummaryRow(
                            label: AppLocalizations.of(
                              context,
                            ).summaryPriorityFee,
                            value: '₱29.00',
                            highlighted: true,
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Divider(color: AppTheme.border),
                        const SizedBox(height: 12),
                        CheckoutSummaryRow(
                          label: AppLocalizations.of(context).summaryTotal,
                          value:
                              '₱${(subtotal + deliveryFee + priorityFee).toStringAsFixed(2)}',
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                CheckoutFooter(
                  enabled:
                      selectedItems.isNotEmpty && !checkout.placingOrder,
                  onPlaceOrder: () async {
                    final confirm = await showCheckoutPlaceOrderDialog(context);
                    if (confirm != true) return;
                    if (!context.mounted) return;

                    final orders = await ref
                        .read(checkoutProvider.notifier)
                        .placeOrder(selectedItems: selectedItems);
                    if (!context.mounted) return;
                    if (orders != null) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.orderConfirmation,
                        (route) => false,
                        arguments: OrderConfirmationRouteArgs(
                          isPickup: deliveryMethod == 1,
                          orders: orders,
                          address: deliveryAddress.displayLine,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
  }
}
