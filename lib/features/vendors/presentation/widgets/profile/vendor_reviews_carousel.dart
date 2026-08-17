import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/navigation/app_router.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';

class MouseDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class VendorReviewsCarousel extends StatefulWidget {
  final List<VendorReview> reviews;

  const VendorReviewsCarousel({super.key, required this.reviews});

  @override
  State<VendorReviewsCarousel> createState() => _VendorReviewsCarouselState();
}

class _VendorReviewsCarouselState extends State<VendorReviewsCarousel>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _autoScrollController;
  Timer? _resumeTimer;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _autoScrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..addListener(_onAutoScrollTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.reviews.isNotEmpty) {
        _startAutoScroll();
      }
    });
  }

  void _onAutoScrollTick() {
    if (!mounted || _isUserInteracting || !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    if (maxScroll <= 0) return;

    position.jumpTo(_autoScrollController.value * maxScroll);
  }

  void _startAutoScroll() {
    _autoScrollController.repeat();
  }

  void _pauseAutoScroll() {
    _resumeTimer?.cancel();
    _isUserInteracting = true;
    _autoScrollController.stop();
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isUserInteracting = false;
        });
        _startAutoScroll();
      }
    });
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _autoScrollController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reviews.isEmpty) return const SizedBox.shrink();

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          if (notification.dragDetails != null) {
            _pauseAutoScroll();
          }
        } else if (notification is ScrollEndNotification) {
          _scheduleResume();
        }
        return false;
      },
      child: Listener(
        onPointerDown: (_) {
          _pauseAutoScroll();
        },
        onPointerUp: (_) {
          _scheduleResume();
        },
        onPointerCancel: (_) {
          _scheduleResume();
        },
        child: SizedBox(
          height: 88,
          child: ScrollConfiguration(
            behavior: MouseDragScrollBehavior(),
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.reviews.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final review = widget.reviews[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.vendorReviews,
                      arguments: VendorReviewsRouteArgs(
                        vendorId: review.vendorId,
                      ),
                    );
                  },
                  child: Container(
                    width: 240,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              review.customerName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFFACC15),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${review.rating}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '"${review.comment}"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
