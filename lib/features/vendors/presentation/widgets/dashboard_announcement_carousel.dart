import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/home/application/announcement_provider.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_announcement_card.dart';
import 'package:palengkego/features/vendors/presentation/widgets/dashboard_sales_card.dart';

/// Paged carousel on the vendor dashboard: sales summary first,
/// then active system announcements.
class DashboardAnnouncementCarousel extends ConsumerStatefulWidget {
  const DashboardAnnouncementCarousel({super.key});

  @override
  ConsumerState<DashboardAnnouncementCarousel> createState() =>
      _DashboardAnnouncementCarouselState();
}

class _DashboardAnnouncementCarouselState
    extends ConsumerState<DashboardAnnouncementCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final announcementsAsync = ref.watch(activeAnnouncementsProvider);
    final announcements = announcementsAsync.value ?? [];

    final int totalPages = 1 + announcements.length;

    return Column(
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: totalPages,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const DashboardSalesCard();
              }
              final announcement = announcements[index - 1];
              return DashboardAnnouncementCard(announcement: announcement);
            },
          ),
        ),
        if (totalPages > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              totalPages,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                width: _currentPage == index ? 20 : 6,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppTheme.primaryGreen
                      : AppTheme.primaryGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
