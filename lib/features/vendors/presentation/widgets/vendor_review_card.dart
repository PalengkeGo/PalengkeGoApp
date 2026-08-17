import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';

class VendorReviewCard extends StatelessWidget {
  final VendorReview review;

  const VendorReviewCard({super.key, required this.review});

  Color _avatarColor(String name) {
    const colors = [
      AppTheme.primaryGreen,
      Color(0xFF1D4ED8),
      Color(0xFF7C3AED),
      AppTheme.warning,
      Color(0xFF065F46),
      Color(0xFF9D174D),
      Color(0xFF1E40AF),
      Color(0xFF92400E),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) {
      final y = (diff.inDays / 365).floor();
      return '$y ${y == 1 ? "year" : "years"} ago';
    }
    if (diff.inDays >= 30) {
      final m = (diff.inDays / 30).floor();
      return '$m ${m == 1 ? "month" : "months"} ago';
    }
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final isProductReview = review.reviewType == ReviewType.product;
    final initial = review.customerName.isNotEmpty
        ? review.customerName[0].toUpperCase()
        : '?';
    final avatarBg = _avatarColor(review.customerName);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + name/date/stars
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: avatarBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            review.customerName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _relativeDate(review.date),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    VendorReviewStarRow(rating: review.rating, size: 13),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Review type tag
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: isProductReview && review.productName != null
                ? VendorReviewTag(
                    icon: Icons.shopping_bag_outlined,
                    label: review.productName!,
                    bg: const Color(0xFFF0FDF4),
                    fg: const Color(0xFF166834),
                  )
                : const VendorReviewTag(
                    icon: Icons.storefront_outlined,
                    label: 'Stall review',
                    bg: AppTheme.surface,
                    fg: AppTheme.textSecondary,
                  ),
          ),

          // Comment
          Text(
            review.comment,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF374151),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class VendorReviewTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;

  const VendorReviewTag({
    super.key,
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class VendorReviewStarRow extends StatelessWidget {
  final double rating;
  final double size;

  const VendorReviewStarRow({
    super.key,
    required this.rating,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && i < rating && (rating - i) >= 0.5;
        return Icon(
          filled
              ? Icons.star_rounded
              : half
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded,
          size: size,
          color: (filled || half)
              ? const Color(0xFFFACC15)
              : const Color(0xFFD1D5DB),
        );
      }),
    );
  }
}
