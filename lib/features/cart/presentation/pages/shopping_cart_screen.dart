import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';
import 'package:palengkego/core/widgets/app_screen_header.dart';

import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/cart/presentation/widgets/cart_item_card.dart';
import 'package:palengkego/features/cart/presentation/widgets/cart_summary_bar.dart';
import 'package:palengkego/features/recipes/presentation/widgets/cart_recipe_suggestions.dart';

import 'package:palengkego/core/widgets/login_required_sheet.dart';

class ShoppingCartScreen extends ConsumerStatefulWidget {
  const ShoppingCartScreen({super.key});

  @override
  ConsumerState<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends ConsumerState<ShoppingCartScreen> {
  void _toggleSelectAll(String vendorName) {
    final itemsAsync = ref.read(cartItemsProvider);
    final items = itemsAsync.value ?? [];
    final vendorItems = items
        .where((item) => item.vendorName == vendorName)
        .toList();
    if (vendorItems.isEmpty) return;

    final allSelected = vendorItems.every((item) => item.selected);
    for (final item in vendorItems) {
      if (allSelected == item.selected) {
        ref
            .read(cartItemsProvider.notifier)
            .toggleSelect(
              item.productId,
              item.vendorName,
              item.productName,
              item.unit,
            );
      }
    }
  }

  void _toggleSelectAllItems() {
    final itemsAsync = ref.read(cartItemsProvider);
    final items = itemsAsync.value ?? [];
    final allSelected =
        items.isNotEmpty && items.every((item) => item.selected);
    ref.read(cartItemsProvider.notifier).selectAll(!allSelected);
  }

  Future<void> _pickAddress() async {
    final currentAddress = ref.read(preferencesProvider).deliveryAddress;
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.setDeliveryAddress);
    if (!mounted) return;
    if (result is DeliveryAddress) {
      ref
          .read(preferencesProvider.notifier)
          .updateAddress(
            primaryAddress: result.primaryAddress.isEmpty
                ? currentAddress.primaryAddress
                : result.primaryAddress,
            streetAddress: result.streetAddress,
            notes: result.notes,
          );
    }
  }

  void _showCheckoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(ctx).cartProceed,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryGreen,
          ),
        ),
        content: const Text(
          'Are you ready to checkout your selected items?',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppLocalizations.of(ctx).cancel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _proceedToCheckoutFlow();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              AppLocalizations.of(ctx).proceed,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _proceedToCheckoutFlow() {
    if (!mounted) return;
    final user = ref.read(authProvider);
    if (user == null) {
      LoginRequiredSheet.show(
        context,
        message: 'You must be logged in to checkout your items.',
        onSuccess: () {
          if (mounted) {
            Navigator.pushNamed(context, AppRoutes.checkout);
          }
        },
      );
    } else {
      Navigator.of(context).pushNamed(AppRoutes.checkout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(cartItemsProvider);
    final preferences = ref.read(preferencesProvider);
    final deliveryAddress = preferences.deliveryAddress;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppScreenHeader(
                    title: AppLocalizations.of(context).cartTitle,
                    trailing: itemsAsync.when(
                      data: (items) => Text(
                        '${items.length} item${items.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickAddress,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(
                                context,
                              ).cartDeliverTo(deliveryAddress.displayLine),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppTheme.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: itemsAsync.when(
                loading: () =>
                    const AsyncLoadingView(color: AppTheme.primaryGreen),
                error: (err, _) => AsyncErrorView(
                  message: 'Error: $err',
                  style: const TextStyle(color: Colors.red),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            size: 64,
                            color: Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context).cartEmptyTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context).cartEmptyHint,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final selectedItems = items
                      .where((item) => item.selected)
                      .toList();
                  final subtotal = selectedItems.fold<double>(
                    0.0,
                    (sum, item) => sum + item.total,
                  );
                  final allSelected =
                      items.isNotEmpty && items.every((item) => item.selected);

                  final vendorGroups = <String, List<CartItem>>{};
                  for (final item in items) {
                    vendorGroups
                        .putIfAbsent(item.vendorName, () => [])
                        .add(item);
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
                          children: [
                            const CartRecipeSuggestions(),
                            for (final entry in vendorGroups.entries) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.storefront_outlined,
                                      size: 18,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Checkbox(
                                        value: entry.value.every(
                                          (item) => item.selected,
                                        ),
                                        activeColor: AppTheme.primaryGreen,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        onChanged: (_) =>
                                            _toggleSelectAll(entry.key),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              for (final item in entry.value)
                                CartItemCard(
                                  item: item,
                                  onToggleSelect: () {
                                    ref
                                        .read(cartItemsProvider.notifier)
                                        .toggleSelect(
                                          item.productId,
                                          item.vendorName,
                                          item.productName,
                                          item.unit,
                                        );
                                  },
                                  onQuantityChange: (newQty) {
                                    final minQty = item.unit == 'kg'
                                        ? 0.125
                                        : 1.0;
                                    if (newQty < minQty) {
                                      ref
                                          .read(cartItemsProvider.notifier)
                                          .updateQuantity(
                                            item.productId,
                                            item.vendorName,
                                            item.productName,
                                            item.unit,
                                            minQty,
                                          );
                                    } else {
                                      ref
                                          .read(cartItemsProvider.notifier)
                                          .updateQuantity(
                                            item.productId,
                                            item.vendorName,
                                            item.productName,
                                            item.unit,
                                            newQty,
                                          );
                                    }
                                  },
                                  onDelete: () {
                                    ref
                                        .read(cartItemsProvider.notifier)
                                        .removeItem(
                                          item.productId,
                                          item.vendorName,
                                          item.productName,
                                          item.unit,
                                        );
                                  },
                                ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                      if (items.isNotEmpty)
                        CartSummaryBar(
                          allSelected: allSelected,
                          subtotal: subtotal,
                          hasSelectedItems: selectedItems.isNotEmpty,
                          onToggleSelectAll: _toggleSelectAllItems,
                          onCheckout: () =>
                              _showCheckoutConfirmationDialog(context),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
