import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
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
  late final Ticker _ticker;
  Duration? _lastTick;
  Timer? _resumeTimer;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _ticker = createTicker(_onAutoScrollTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant VendorReviewsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    final animate =
        widget.reviews.length > 1 &&
        !_isUserInteracting &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context);
    if (animate && !_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onAutoScrollTick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null ||
        _isUserInteracting ||
        widget.reviews.length < 2 ||
        !_scrollController.hasClients ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      return;
    }
    final delta = elapsed - previous;
    // Discard background/route pauses instead of jumping on the first frame back.
    if (delta > const Duration(milliseconds: 100)) return;
    final position = _scrollController.position;
    if (position.isScrollingNotifier.value) return;
    position.jumpTo(position.pixels + delta.inMicroseconds / 1000000 * 20);
  }

  void _pauseAutoScroll() {
    _resumeTimer?.cancel();
    _isUserInteracting = true;
    _syncTicker();
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _isUserInteracting = false;
        _syncTicker();
      }
    });
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _ticker.dispose();
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
        } else if (notification is ScrollEndNotification &&
            _isUserInteracting) {
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
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemExtent: 252,
              // Lazy repetition has no end-to-start snap. Reduced motion stays finite.
              itemCount:
                  widget.reviews.length < 2 ||
                      MediaQuery.disableAnimationsOf(context) ||
                      MediaQuery.accessibleNavigationOf(context)
                  ? widget.reviews.length
                  : null,
              itemBuilder: (context, index) {
                final review = widget.reviews[index % widget.reviews.length];
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
                    margin: const EdgeInsets.only(right: 12),
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
                            Expanded(
                              child: Text(
                                review.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),

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
