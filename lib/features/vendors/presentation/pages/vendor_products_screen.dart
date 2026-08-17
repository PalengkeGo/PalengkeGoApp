import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/core/utils/unit_helper.dart';
import 'package:palengkego/core/widgets/empty_state.dart';
import '../widgets/vendor_screen_header.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/navigation/app_router.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';

/// Vendor Products Screen
/// Shows all vendor products with stock toggle.
class VendorProductsScreen extends ConsumerStatefulWidget {
  const VendorProductsScreen({super.key});

  @override
  ConsumerState<VendorProductsScreen> createState() =>
      _VendorProductsScreenState();
}

class _VendorProductsScreenState extends ConsumerState<VendorProductsScreen> {
  String _selectedFilter = 'All Products';
  String _searchQuery = '';
  String? _vendorId;

  @override
  Widget build(BuildContext context) {
    _vendorId = ref.watch(currentVendorIdProvider);
    final productsAsync = _vendorId == null
        ? const AsyncValue<List<VendorProduct>>.data([])
        : ref.watch(vendorProductsProvider(_vendorId!));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const VendorScreenHeader(title: 'My Products'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: appInputDecoration(
                  hintText: 'Search products...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.muted,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppTheme.muted,
                    size: 20,
                  ),
                  fillColor: AppTheme.scaffoldBackground,
                  borderless: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _buildFilterTab(
                    'All Products',
                    _selectedFilter == 'All Products',
                  ),
                  const SizedBox(width: 24),
                  _buildFilterTab(
                    'Out of Stock',
                    _selectedFilter == 'Out of Stock',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  productsAsync.when(
                    data: (products) {
                      final filteredProducts = products.where((product) {
                        final matchesFilter = switch (_selectedFilter) {
                          'Out of Stock' => !product.isActive,
                          _ => true,
                        };
                        final matchesSearch = product.name
                            .toLowerCase()
                            .contains(_searchQuery.trim().toLowerCase());
                        return matchesFilter && matchesSearch;
                      }).toList();

                      if (filteredProducts.isEmpty) {
                        return const EmptyState(
                          title: 'No products match this filter yet.',
                          titleStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _buildProductGridCard(product);
                        },
                      );
                    },
                    loading: () =>
                        const AsyncLoadingView(color: AppTheme.primaryGreen),
                    error: (error, _) =>
                        AsyncErrorView(message: 'Error: $error'),
                  ),
                  Positioned(
                    right: 20,
                    bottom: 20,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.vendorAddProduct,
                        );
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppTheme.primaryGreen : AppTheme.muted,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(width: 40, height: 2, color: AppTheme.primaryGreen),
        ],
      ),
    );
  }

  Widget _buildProductGridCard(VendorProduct product) {
    final formatCurrency = NumberFormat.currency(symbol: '₱', decimalDigits: 0);
    final isPiece = UnitHelper.isPieceProduct(product);
    final imageColor = isPiece
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFF0FDF4);
    final unitLabel = UnitHelper.getUnitString(isPiece);

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.vendorAddProduct,
          arguments: VendorAddProductRouteArgs(existingProduct: product),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(16, 24, 40, 0.04),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: imageColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
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
                        ],
                      ),
                    ),
                  ),
                  // Low Stock Warning
                  if (product.isActive &&
                      product.stockQuantity > 0 &&
                      product.isLowStock)
                    Positioned(
                      top: 8,
                      left: product.hasDiscount
                          ? 60
                          : 8, // Shift right if discount tag exists
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B), // Amber warning
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
                  // Discount Tag
                  if (product.hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${product.discountPercentage!.toInt()}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  // Edit badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.08),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (product.hasDiscount)
                    Text(
                      '${formatCurrency.format(product.price)}/$unitLabel',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    '${formatCurrency.format(product.discountedPrice)}/$unitLabel',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.stockQuantity > 0
                              ? 'Stock: ${product.stockQuantity % 1 == 0 ? product.stockQuantity.toInt().toString() : product.stockQuantity.toStringAsFixed(2)} $unitLabel'
                              : (product.isActive
                                    ? 'In Stock'
                                    : 'Out of Stock'),
                          style: TextStyle(
                            fontSize: 10,
                            color: product.isActive
                                ? AppTheme.statusOpen
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.75,
                        alignment: Alignment.centerRight,
                        child: Switch(
                          value: product.isActive && product.stockQuantity > 0,
                          onChanged: product.stockQuantity > 0
                              ? (value) async {
                                  if (_vendorId == null) return;
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final updated = product.copyWith(
                                    isActive: value,
                                  );
                                  await ref
                                      .read(
                                        vendorProductsManagerProvider(
                                          _vendorId!,
                                        ),
                                      )
                                      .updateProduct(updated);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${product.name} is now ${value ? 'in stock' : 'out of stock'}.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              : null,
                          activeThumbColor: AppTheme.primaryGreen,
                          activeTrackColor: AppTheme.primaryGreen.withValues(
                            alpha: 0.25,
                          ),
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
    );
  }
}
