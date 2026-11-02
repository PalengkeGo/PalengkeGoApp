import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/features/home/presentation/widgets/discounted_item_card.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/market/domain/market_product.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';

class SpecialOffersScreen extends ConsumerWidget {
  const SpecialOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(discountedProductsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Special Offers'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: offers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load offers: $error')),
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('There are no special offers right now.'));
          }
          final productsByStall = <String, List<MarketProduct>>{};
          for (final product in products) {
            productsByStall.putIfAbsent(product.vendorId, () => []).add(product);
          }
          final stalls = productsByStall.entries.toList();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            itemCount: stalls.length,
            separatorBuilder: (_, _) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final stall = stalls[index];
              return _OfferStallSection(
                vendorId: stall.key,
                products: stall.value,
              );
            },
          );
        },
      ),
    );
  }
}

class _OfferStallSection extends ConsumerWidget {
  const _OfferStallSection({required this.vendorId, required this.products});

  final String vendorId;
  final List<MarketProduct> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(vendorProfileProvider(vendorId)).value;
    final stallName = vendor?.name.trim().isNotEmpty == true
        ? vendor!.name
        : 'Stall';
    final stallImage = vendor?.avatarUrl.trim().isNotEmpty == true
        ? vendor!.avatarUrl
        : vendor?.imageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.vendorProfile,
              arguments: VendorProfileRouteArgs(vendorId: vendorId),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: (stallImage?.isNotEmpty ?? false)
                          ? AdaptiveImage(stallImage, fit: BoxFit.cover)
                          : const ColoredBox(
                              color: Color(0xFFE8F3EF),
                              child: Icon(Icons.storefront_rounded, color: Color(0xFF0B5D4B)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stallName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${vendor?.category ?? 'Market stall'} · ${products.length} ${products.length == 1 ? 'offer' : 'offers'}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF0B5D4B)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = ((constraints.maxWidth + 12) / 172).floor().clamp(1, 4);
            final cardWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 230,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final product = products[index];
                return DiscountedItemCard(
                  width: cardWidth,
                  product: product,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.vendorProfile,
                    arguments: VendorProfileRouteArgs(
                      vendorId: product.vendorId,
                      highlightProductId: product.id,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
