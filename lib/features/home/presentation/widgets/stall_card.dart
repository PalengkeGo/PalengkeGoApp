import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_profile_screen.dart';

class StallCard extends StatefulWidget {
  final MarketVendor vendor;
  final String? selectedCategory;

  const StallCard({super.key, required this.vendor, this.selectedCategory});

  @override
  State<StallCard> createState() => _StallCardState();
}

class _StallCardState extends State<StallCard> {
  @override
  Widget build(BuildContext context) {
    final rating = widget.vendor.rating.toStringAsFixed(1);
    final category = widget.vendor.category;
    final stallLocation = _stallLabelFor(widget.vendor.id);
    final isOpen = widget.vendor.isOpen;
    final status = isOpen ? 'OPEN' : 'CLOSED';

    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        if (!isOpen) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text(
                'This stall is currently closed and will open soon.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        Navigator.of(context).push(
          PageTransitions.slideFromRight(
            VendorProfileScreen(
              vendorId: widget.vendor.id,
              filterCategory: widget.selectedCategory,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 163,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: SizedBox.expand(
                      child: AdaptiveImage(
                        widget.vendor.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Center(
                            child: Icon(
                              Icons.image_rounded,
                              color: AppTheme.muted,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.05),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      height: 23,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isOpen ? AppTheme.statusOpen : AppTheme.muted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 115,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Top group ─ Expanded + ClipRect prevents any overflow
                    // from pushing the bottom row off the card.
                    Expanded(
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.vendor.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGreen,
                                  height: 1.2,
                                ),
                              ),
                              if (widget.vendor.reviewCount > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 11,
                                      color: Color(0xFFFBBF24),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '(${widget.vendor.reviewCount})',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.vendor.topReviewText != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '"${widget.vendor.topReviewText}"',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                      color: AppTheme.muted,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom row ─ always pinned, never overflowed
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stallLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color.fromRGBO(11, 55, 43, 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stallLabelFor(String? vendorId) {
    switch (vendorId) {
      case 'v1':
        return 'Stall 4';
      case 'v2':
        return 'Block 15 | Stall 2';
      case 'v3':
        return 'Stall #33';
      case 'v4':
        return 'Block 3 | Stall 4';
      case 'v5':
        return 'Block 7 | Stall 2';
      case 'v6':
        return 'Block 7 | Stall 1';
      default:
        return 'Market Stall';
    }
  }
}
