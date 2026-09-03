import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/utils/unit_helper.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';
import 'package:palengkego/features/vendors/presentation/widgets/add_to_cart_bottom_sheet.dart';

class VendorProfileProductCard extends StatelessWidget {
  final VendorProduct product;
  final String vendorName;
  final bool isStallOpen;

  const VendorProfileProductCard({
    super.key,
    required this.product,
    required this.vendorName,
    this.isStallOpen = true,
  });

  Future<void> _handleAddToCart(BuildContext context) async {
    if (product.stockQuantity <= 0) return;

    if (!isStallOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$vendorName is currently closed.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final result = await AddToCartBottomSheet.show(
      context,
      vendorName: vendorName,
      product: product,
    );
    if (result == AddToCartResult.cancelled || !context.mounted) return;

    if (result == AddToCartResult.addedLoginRequired) {
      // The item was saved to the device cart, but it was the user's first add
      // while signed out — prompt login so their details can be saved early.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in or sign up to continue'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      await _showLoginPrompt(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Popup asking a guest to create an account / log in after adding their
  /// first item. The item is already in the device cart, so "Maybe later" is
  /// safe — it will merge on the next login.
  Future<void> _showLoginPrompt(BuildContext context) async {
    final goLogin = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Create an account to keep this',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This item was saved to your cart. Log in or sign up so your '
          'information is ready when you order.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Login / Sign up'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Maybe later',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
    if (goLogin == true && context.mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pushNamed(AppRoutes.login);
      } catch (_) {
        // Login route isn't reachable here (isolated widget test) — harmless.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = product.price.toInt();
    final isAvailable = product.stockQuantity > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isAvailable ? () => _handleAddToCart(context) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF3F4F6)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: UnitHelper.isPieceProduct(product)
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFF0FDF4),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (product.imageUrl.isNotEmpty)
                          AdaptiveImage(product.imageUrl, fit: BoxFit.cover)
                        else
                          const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 40,
                              color: AppTheme.muted,
                            ),
                          ),
                        // Low Stock badge (≤10% of initial, or ≤10 absolute if initial unknown)
                        if (product.isActive &&
                            product.stockQuantity > 0 &&
                            (() {
                              final init = product.initialStockQuantity;
                              return init > 0
                                  ? product.stockQuantity / init <= 0.10
                                  : product.stockQuantity <= 10;
                            })())
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'LOW STOCK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        if (product.hasDiscount)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '-${product.discountPercentage!.toInt()}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            product.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        if (product.stockQuantity == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Out of stock',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          )
                        else if (product.isLowStock)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Text(
                              'Only ${product.stockQuantity % 1 == 0 ? product.stockQuantity.toInt().toString() : product.stockQuantity.toStringAsFixed(2)} left',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (product.hasDiscount)
                                Text(
                                  '₱$price/${UnitHelper.getUnitString(UnitHelper.isPieceProduct(product))}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.muted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Text(
                                '₱${product.discountedPrice.toInt()}/${UnitHelper.getUnitString(UnitHelper.isPieceProduct(product))}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGreen,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? AppTheme.primaryGreen
                                : const Color(0xFFD1D5DB),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
