import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'vendor_review_filter.dart';

class VendorReviewsEmptyState extends StatelessWidget {
  const VendorReviewsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.rate_review_outlined,
      iconBackground: Color(0xFFF0FDF4),
      iconColor: AppTheme.primaryGreen,
      iconSize: 36,
      iconContainerRadius: 20,
      iconSpacing: 20,
      padding: EdgeInsets.all(40),
      title: 'No reviews yet',
      titleStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
      subtitle:
          'When customers leave feedback on\nyour stall or products, they appear here.',
      subtitleStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppTheme.muted,
        height: 1.6,
      ),
    );
  }
}

class VendorReviewsFilteredEmptyState extends StatelessWidget {
  final VendorReviewFilter filter;

  const VendorReviewsFilteredEmptyState({super.key, required this.filter});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.filter_list_off_rounded,
      iconColor: const Color(0xFFD1D5DB),
      iconSize: 40,
      iconSpacing: 16,
      padding: const EdgeInsets.all(40),
      title: 'No ${reviewFilterLabel(filter)} reviews',
      titleStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }
}
