import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/widgets/empty_state.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/recipes/application/recipe_purchases_provider.dart';
import 'package:palengkego/features/recipes/presentation/widgets/recommended_product_card.dart';

class RecommendedIngredientStoresScreen extends ConsumerWidget {
  const RecommendedIngredientStoresScreen({
    super.key,
    required this.ingredientName,
    this.recipeTitle,
  });

  final String ingredientName;
  final String? recipeTitle;

  String _formatStock(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
  }

  void _showOrderBottomSheet(
    BuildContext context,
    WidgetRef ref,
    RecommendedIngredientProduct item,
  ) {
    final maxStock = item.product.stockQuantity;
    final isOutOfStock = maxStock <= 0;
    int quantity = isOutOfStock ? 0 : 1;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalPrice = item.product.discountedPrice * quantity;
            final reachesLimit = !isOutOfStock && quantity >= maxStock;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AdaptiveImage(
                          item.product.imageUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            width: 64,
                            height: 64,
                            color: AppTheme.surfaceContainerLow,
                            child: const Icon(
                              Icons.restaurant,
                              color: AppTheme.muted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Stall: ${item.vendor.name}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '₱${item.product.discountedPrice.toStringAsFixed(2)} / ${item.product.unit}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                if (item.product.hasDiscount) ...[ 
                                  const SizedBox(width: 6),
                                  Text(
                                    '₱${item.product.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.muted,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  isOutOfStock
                                      ? 'Out of Stock'
                                      : 'Stock: ${_formatStock(maxStock)} ${item.product.unit} left',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: (isOutOfStock || item.product.isLowStock)
                                        ? const Color(0xFFDC2626)
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                                if (!isOutOfStock && item.product.isLowStock) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFFCA5A5)),
                                    ),
                                    child: const Text(
                                      'Low Stock',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Quantity Selector Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Quantity:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: (!isOutOfStock && quantity > 1)
                                  ? () => setModalState(() => quantity--)
                                  : null,
                              icon: const Icon(Icons.remove, size: 18),
                              color: (!isOutOfStock && quantity > 1)
                                  ? AppTheme.textPrimary
                                  : AppTheme.muted,
                            ),
                            Text(
                              '$quantity',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              onPressed: (isOutOfStock || reachesLimit)
                                  ? () {
                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isOutOfStock
                                                ? '${item.product.name} is currently out of stock.'
                                                : 'Maximum stock reached. Only ${_formatStock(maxStock)} ${item.product.unit} left.',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  : () {
                                      setModalState(() {
                                        quantity++;
                                      });
                                      if (quantity >= maxStock) {
                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Maximum available stock reached (${_formatStock(maxStock)} ${item.product.unit}).',
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.add, size: 18),
                              color: (isOutOfStock || reachesLimit)
                                  ? AppTheme.muted
                                  : AppTheme.primaryGreen,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Add & Scratch-off CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (isOutOfStock || quantity <= 0)
                          ? null
                          : () async {
                              final cartItem = CartItem(
                                productId: item.product.id,
                                vendorName: item.vendor.name,
                                productName: item.product.name,
                                price: item.product.discountedPrice,
                                unit: item.product.unit,
                                image: item.product.imageUrl,
                                quantity: quantity.toDouble(),
                                stockQuantity: item.product.stockQuantity,
                              );

                              await ref
                                  .read(cartItemsProvider.notifier)
                                  .addToCart(cartItem);

                              // Mark ingredient as purchased for instant recipe scratch-off
                              ref
                                  .read(manualPurchasedIngredientsProvider.notifier)
                                  .markAsPurchased(ingredientName);

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.primaryGreen,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Added ${item.product.name}! "$ingredientName" scratched off!',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (isOutOfStock || quantity <= 0)
                            ? AppTheme.muted
                            : AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isOutOfStock
                            ? 'Out of Stock'
                            : 'Add to Cart • ₱${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendationsAsync = ref.watch(
      recommendedStoresForIngredientProvider(ingredientName),
    );
    final cartItems = ref.watch(cartItemsProvider).value ?? [];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Recommended "$ingredientName"',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                  color: AppTheme.textPrimary,
                ),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
              ),
              if (cartItems.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${cartItems.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: recommendationsAsync.when(
        loading: () => const AsyncLoadingView(color: AppTheme.primaryGreen),
        error: (err, stack) =>
            AsyncErrorView(message: 'Error loading recommendations: $err'),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              title: 'No stalls found for this ingredient yet.',
              titleStyle: TextStyle(color: AppTheme.textSecondary),
            );
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Recipe context pill header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_offer_rounded,
                          color: Color(0xFF059669),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            recipeTitle != null
                                ? 'Stores carrying $ingredientName for "$recipeTitle"'
                                : 'Available market stalls for $ingredientName',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2-Column Product Cards Grid (Matching Image 2)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.80,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = items[index];
                    return RecommendedProductCard(
                      item: item,
                      onTap: () => _showOrderBottomSheet(context, ref, item),
                      onAddToCart: () =>
                          _showOrderBottomSheet(context, ref, item),
                    );
                  }, childCount: items.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
