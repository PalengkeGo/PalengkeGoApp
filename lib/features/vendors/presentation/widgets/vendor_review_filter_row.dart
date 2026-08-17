import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';
import 'vendor_review_filter.dart';

class VendorReviewFilterRow extends StatelessWidget {
  final VendorReviewFilter selected;
  final ValueChanged<VendorReviewFilter> onChanged;
  final List<VendorReview> allReviews;

  const VendorReviewFilterRow({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.allReviews,
  });

  @override
  Widget build(BuildContext context) {
    // List of (filter, label) pairs as explicit objects to avoid record syntax.
    final filterDefs = <MapEntry<VendorReviewFilter, String>>[
      const MapEntry(VendorReviewFilter.all, 'All'),
      const MapEntry(VendorReviewFilter.five, '5★'),
      const MapEntry(VendorReviewFilter.four, '4★'),
      const MapEntry(VendorReviewFilter.three, '3★'),
      const MapEntry(VendorReviewFilter.two, '2★'),
      const MapEntry(VendorReviewFilter.one, '1★'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filterDefs.map((entry) {
          final filterVal = entry.key;
          final label = entry.value;
          final isSelected = selected == filterVal;
          final count = countReviews(allReviews, filterVal);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(filterVal),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF374151),
                      ),
                    ),
                    if (filterVal != VendorReviewFilter.all) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
