import 'package:palengkego/core/theme/app_theme.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';
import 'vendor_review_card.dart';

/// Rating summary card with an interactive star-distribution diagram.
///
/// Tapping a star row (e.g. the "5" row) filters the diagram to that star's
/// reviews only: the other bars animate away, and the headline average/count
/// recompute from the filtered subset. Tapping the same row again — or the
/// "Show all" pill — restores the full distribution.
///
/// [onStarSelected] is called with the tapped star (null = show all) so a
/// host screen can filter its visible review list in lock-step with the
/// diagram. The card is fully self-contained without it.
class VendorReviewSummaryCard extends StatefulWidget {
  final List<VendorReview> reviews;
  final ValueChanged<int?>? onStarSelected;

  const VendorReviewSummaryCard({
    super.key,
    required this.reviews,
    this.onStarSelected,
  });

  @override
  State<VendorReviewSummaryCard> createState() => _VendorReviewSummaryCardState();
}

class _VendorReviewSummaryCardState extends State<VendorReviewSummaryCard> {
  static const _animationDuration = Duration(milliseconds: 350);
  static const _animationCurve = Curves.easeOutCubic;

  /// Star the diagram is currently filtered to; null = full distribution.
  int? _activeStar;

  bool get _hasActive => _activeStar != null;

  /// Reviews shown for the active filter (all reviews when none is active).
  List<VendorReview> get _visibleReviews {
    final star = _activeStar;
    if (star == null) return widget.reviews;
    return widget.reviews.where((r) => r.rating.round() == star).toList();
  }

  /// Average rating of the visible (possibly filtered) subset.
  double get _displayAvg {
    final visible = _visibleReviews;
    if (visible.isEmpty) return 0;
    return visible.fold(0.0, (sum, r) => sum + r.rating) / visible.length;
  }

  /// Count for a star within the CURRENTLY-VISIBLE (possibly filtered) subset,
  /// so picking e.g. "5" folds the other bars toward zero instead of showing
  /// the full distribution.
  int _countForStar(int star) =>
      _visibleReviews.where((r) => r.rating.round() == star).length;

  void _toggleStar(int star) {
    final next = _activeStar == star ? null : star;
    setState(() {
      _activeStar = next;
    });
    widget.onStarSelected?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final counts = [5, 4, 3, 2, 1].map(_countForStar).toList();
    final maxCount = counts.reduce(math.max).clamp(1, 999999);
    final avg = _displayAvg;
    final total = _visibleReviews.length;
    final star = _activeStar;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: big number + stars + total. The block crossfades when
              // the filter changes so the recompute reads as a transition.
              AnimatedSwitcher(
                duration: _animationDuration,
                child: Column(
                  key: ValueKey('summary-$star-$total'),
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      avg.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryGreen,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Show the tapped star exactly when filtered; otherwise
                    // the fractional average.
                    VendorReviewStarRow(rating: (star ?? avg).toDouble(), size: 16),
                    const SizedBox(height: 6),
                    Text(
                      '$total ${total == 1 ? "review" : "reviews"}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Right: distribution bars (tappable, animated).
              Expanded(
                child: Column(
                  children: List.generate(5, (i) {
                    final barStar = 5 - i;
                    return _starRow(
                      star: barStar,
                      count: counts[i],
                      maxCount: maxCount,
                    );
                  }),
                ),
              ),
            ],
          ),
          // "Show all" affordance — slides in only while a filter is active.
          AnimatedSwitcher(
            duration: _animationDuration,
            transitionBuilder: (child, animation) =>
                SizeTransition(sizeFactor: animation, child: child),
            child: star == null
                ? const SizedBox.shrink(key: ValueKey('summary-show-all-off'))
                : Padding(
                    key: const ValueKey('summary-show-all-on'),
                    padding: EdgeInsets.zero,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _ShowAllPill(
                        star: star,
                        onTap: () => _toggleStar(star),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _starRow({
    required int star,
    required int count,
    required int maxCount,
  }) {
    final isActive = _activeStar == star;
    final isDimmed = _hasActive && !isActive;
    // When a filter is active, only the selected star keeps its bar/count.
    final displayCount = _hasActive ? (isActive ? count : 0) : count;
    final fraction = _hasActive
        ? (isActive ? 1.0 : 0.0)
        : count / maxCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleStar(star),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: _animationDuration,
            curve: _animationCurve,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFF0FDF4) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  '$star',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive
                        ? AppTheme.primaryGreen
                        : isDimmed
                        ? AppTheme.muted
                        : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.star_rounded,
                  size: 11,
                  color: isDimmed
                      ? AppTheme.muted
                      : const Color(0xFFFACC15),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: fraction),
                    duration: _animationDuration,
                    curve: _animationCurve,
                    builder: (context, value, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: value,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDimmed ? AppTheme.muted : AppTheme.primaryGreen,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 18,
                  child: Text(
                    '$displayCount',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isDimmed
                          ? AppTheme.muted
                          : isActive
                          ? AppTheme.primaryGreen
                          : AppTheme.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet pill that restores the full distribution while a star filter is
/// active (e.g. "5★ · show all").
class _ShowAllPill extends StatelessWidget {
  const _ShowAllPill({required this.star, required this.onTap});

  final int star;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$star★',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'show all',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
