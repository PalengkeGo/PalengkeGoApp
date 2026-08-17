import 'package:palengkego/core/theme/app_theme.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';
import 'vendor_review_card.dart';

class VendorReviewSummaryCard extends StatelessWidget {
  final List<VendorReview> reviews;

  const VendorReviewSummaryCard({super.key, required this.reviews});

  double get _avgRating {
    if (reviews.isEmpty) return 0;
    return reviews.fold(0.0, (s, r) => s + r.rating) / reviews.length;
  }

  int _countForStar(int star) =>
      reviews.where((r) => r.rating.round() == star).length;

  @override
  Widget build(BuildContext context) {
    final avg = _avgRating;
    final total = reviews.length;
    final counts = [5, 4, 3, 2, 1].map(_countForStar).toList();
    final maxCount = counts.reduce(math.max).clamp(1, 999999);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: big number + stars + total
          Column(
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
              VendorReviewStarRow(rating: avg, size: 16),
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
          const SizedBox(width: 20),
          // Right: distribution bars
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final star = 5 - i;
                final count = counts[i];
                final fraction = count / maxCount;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(
                        '$star',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.star_rounded,
                        size: 11,
                        color: Color(0xFFFACC15),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction,
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryGreen,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 18,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
