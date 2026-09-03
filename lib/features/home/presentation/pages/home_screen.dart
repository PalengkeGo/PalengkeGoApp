import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/widgets/animated_entrance.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/profile/application/blocked_vendors_provider.dart';
import 'package:palengkego/features/home/presentation/widgets/home_header.dart';
import 'package:palengkego/features/home/presentation/widgets/search_field.dart';
import 'package:palengkego/features/home/presentation/widgets/stall_card.dart';
import 'package:palengkego/features/home/presentation/widgets/discounted_item_card.dart';
import 'package:palengkego/features/home/application/announcement_provider.dart';
import 'package:palengkego/features/home/presentation/widgets/announcement_carousel.dart';
import 'package:palengkego/core/navigation/app_routes.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback onMarketSelected;
  const HomeScreen({super.key, required this.onMarketSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(allVendorsProvider);
    final blockedIds = ref.watch(blockedVendorsProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: Stack(
        children: [
          // Emerald Gradient Header Background fading seamlessly downwards
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 330,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0B372B),
                    Color(0xFF114234),
                    Color(0xFF1A4D3D),
                    Color(0xFF265F4C),
                    Color(0xFF3B7B64),
                    Color(0xFF64A18B),
                    Color(0xFF9DC7B7),
                    Color(0xFFD6EBE2),
                    AppTheme.scaffoldBackground,
                  ],
                  stops: [0.0, 0.20, 0.40, 0.55, 0.70, 0.82, 0.91, 0.96, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const HomeHeader(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 6, 20, 16),
                  child: SearchField(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Announcements / Special Offers Carousel
                        AnimatedEntrance(
                      index: 0,
                      child: Consumer(
                        builder: (context, ref, _) {
                          final announcementsAsync = ref.watch(
                            activeAnnouncementsProvider,
                          );

                          return announcementsAsync.when(
                            loading: () => const SizedBox(
                              height: 180,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (err, stack) => const SizedBox.shrink(),
                            data: (announcements) {
                              if (announcements.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return AnnouncementCarousel(
                                announcements: announcements,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    // Special Offers Section
                    Consumer(
                      builder: (context, ref, _) {
                        final discountedAsync = ref.watch(
                          discountedProductsProvider,
                        );

                        return discountedAsync.when(
                          loading: () => const SizedBox(
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (err, stack) =>
                              AsyncErrorView(message: 'Error: $err'),
                          data: (discountedProducts) {
                            if (discountedProducts.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child: Text(
                                    'Special Offers',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 240,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: discountedProducts.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final product = discountedProducts[index];
                                      return AnimatedEntrance(
                                        index: index + 1,
                                        child: DiscountedItemCard(
                                          product: product,
                                          onTap: () {
                                            Navigator.pushNamed(
                                              context,
                                              AppRoutes.vendorProfile,
                                              arguments: VendorProfileRouteArgs(
                                                vendorId: product.vendorId,
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            );
                          },
                        );
                      },
                    ),

                    // Popular Stalls Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).homePopularStalls,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: onMarketSelected,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View All',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Popular Stalls Grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: vendorsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, stack) =>
                            AsyncErrorView(message: 'Error: $err'),
                        data: (allVendors) {
                          final vendors = allVendors
                              .where((v) => !blockedIds.contains(v.id))
                              .toList();
                          return GridView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.55,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: vendors.take(4).length,
                            itemBuilder: (context, index) {
                              final vendor = vendors[index];
                              return AnimatedEntrance(
                                index: index + 1,
                                child: StallCard(vendor: vendor),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);
  }
}
