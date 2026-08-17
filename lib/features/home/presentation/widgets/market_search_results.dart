import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/home/application/search_provider.dart';
import 'package:palengkego/features/home/presentation/widgets/market_empty_state.dart';
import 'package:palengkego/features/market/domain/market_product.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/navigation/app_router.dart';

/// Combined product + stall search results for an active query.
class MarketCombinedSearchResults extends ConsumerWidget {
  final String query;

  const MarketCombinedSearchResults({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(appSearchProvider(query));

    return resultsAsync.when(
      loading: () => const AsyncLoadingView(),
      error: (err, _) => AsyncErrorView(message: 'Error: $err'),
      data: (results) {
        if (results.isEmpty) return MarketEmptyState(query: query);

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Results',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    Text(
                      '${results.length} found',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              sliver: SliverList.separated(
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 0,
                  color: AppTheme.surfaceContainerLow,
                ),
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final result = results[i];
                  return result.isProduct
                      ? MarketProductTile(product: result.product!)
                      : MarketVendorTile(vendor: result.vendor!);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Search result tile for a matching product.
class MarketProductTile extends StatelessWidget {
  final MarketProduct product;

  const MarketProductTile({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.vendorProfile,
        arguments: VendorProfileRouteArgs(vendorId: product.vendorId),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AdaptiveImage(
                product.imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: Container(
                  width: 48,
                  height: 48,
                  color: const Color(0xFFF3F4F6),
                  child: const Icon(
                    Icons.image_rounded,
                    size: 20,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 2),
                  Text(
                    product.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₱${product.discountedPrice.toStringAsFixed(0)}/${product.unit}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                // Product badge
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Product',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search result tile for a matching stall.
class MarketVendorTile extends StatelessWidget {
  final MarketVendor vendor;

  const MarketVendorTile({super.key, required this.vendor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.vendorProfile,
        arguments: VendorProfileRouteArgs(vendorId: vendor.id),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AdaptiveImage(
                vendor.imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: Container(
                  width: 48,
                  height: 48,
                  color: const Color(0xFFF3F4F6),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 20,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vendor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Stall Holder',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vendor.category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Stall',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}
