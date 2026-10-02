import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/widgets/animated_entrance.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/profile/application/blocked_vendors_provider.dart';
import 'package:palengkego/features/home/presentation/widgets/home_header.dart';
import 'package:palengkego/features/home/presentation/widgets/search_field.dart';
import 'package:palengkego/features/home/presentation/widgets/stall_card.dart';
import 'package:palengkego/features/home/presentation/widgets/discounted_item_card.dart';
import 'package:palengkego/features/home/application/announcement_provider.dart';
import 'package:palengkego/features/home/presentation/widgets/announcement_carousel.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/widgets/skeleton_loading.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback onMarketSelected;
  const HomeScreen({super.key, required this.onMarketSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Header Background Gradient fading downwards towards announcement cards
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
                    Color(0xFF06231D),
                    Color(0xFF064438),
                    Color(0xFF076653),
                    Color(0xFF388675),
                    Color(0xFF6DAEA0),
                    Color(0xFFA7D1C7),
                    Color(0xFFD6EAE5),
                    AppTheme.scaffoldBackground,
                  ],
                  stops: [0.0, 0.22, 0.50, 0.70, 0.83, 0.92, 0.97, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HomeHeader(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 6, 20, 16),
                  child: SearchField(),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppTheme.primaryGreen,
                    onRefresh: () async {
                      ref.read(dataRefreshSignal.notifier).notify();
                      try {
                        await Future.wait([
                          ref.read(allVendorsProvider.future),
                          ref.read(allProductsProvider.future),
                          ref.read(activeAnnouncementsProvider.future),
                        ]);
                      } catch (_) {
                        AppServices.showError(
                          'Unable to refresh. Please try again.',
                        );
                      }
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.only(bottom: 84),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  skipLoadingOnReload: true,
                                  loading: () => const SizedBox(
                                    height: 180,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  error: (err, stack) =>
                                      const SizedBox.shrink(),
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
                              final cardHeight =
                                  (240.0 *
                                          MediaQuery.textScalerOf(
                                            context,
                                          ).scale(1.0))
                                      .clamp(240.0, 320.0);

                              return discountedAsync.when(
                                skipLoadingOnReload: true,
                                loading: () => SizedBox(
                                  height: cardHeight,
                                  child: ProductCardSkeletonRow(
                                    height: cardHeight,
                                  ),
                                ),
                                error: (err, stack) =>
                                    AsyncErrorView(message: 'Error: $err'),
                                data: (discountedProducts) {
                                  if (discountedProducts.isEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
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
                                        height: cardHeight,
                                        child: ListView.separated(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                          ),
                                          scrollDirection: Axis.horizontal,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          itemCount: discountedProducts.length,
                                          separatorBuilder: (context, index) =>
                                              const SizedBox(width: 12),
                                          itemBuilder: (context, index) {
                                            final product =
                                                discountedProducts[index];
                                            return AnimatedEntrance(
                                              index: index + 1,
                                              child: DiscountedItemCard(
                                                product: product,
                                                onTap: () {
                                                  Navigator.pushNamed(
                                                    context,
                                                    AppRoutes.vendorProfile,
                                                    arguments:
                                                        VendorProfileRouteArgs(
                                                          vendorId:
                                                              product.vendorId,
                                                          highlightProductId:
                                                              product.id,
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
                                    AppLocalizations.of(
                                      context,
                                    ).homePopularStalls,
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
                            child: Consumer(
                              builder: (context, ref, _) {
                                final popularAsync = ref.watch(
                                  popularVendorsProvider,
                                );
                                final blockedIds = ref.watch(
                                  blockedVendorsProvider,
                                );

                                return popularAsync.when(
                                  skipLoadingOnReload: true,
                                  loading: () =>
                                      const VendorCardSkeletonGrid(itemCount: 4),
                                  error: (err, stack) =>
                                      AsyncErrorView(message: 'Error: $err'),
                                  data: (popularVendors) {
                                    final vendors = popularVendors
                                        .where(
                                          (v) => !blockedIds.contains(v.id),
                                        )
                                        .toList();
                                    final displayCount = vendors.length > 8
                                        ? 8
                                        : vendors.length;

                                    return LayoutBuilder(
                                      builder: (context, constraints) {
                                        if (constraints.maxWidth <= 0) {
                                          return const SizedBox.shrink();
                                        }
                                        return GridView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          gridDelegate:
                                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                                maxCrossAxisExtent: 230,
                                                childAspectRatio: 0.55,
                                                crossAxisSpacing: 12,
                                                mainAxisSpacing: 16,
                                              ),
                                          itemCount: displayCount,
                                          itemBuilder: (context, index) {
                                            final vendor = vendors[index];
                                            return AnimatedEntrance(
                                              index: index + 1,
                                              child: StallCard(vendor: vendor),
                                            );
                                          },
                                        );
                                      },
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
