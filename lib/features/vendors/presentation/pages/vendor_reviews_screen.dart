import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/vendors/application/vendor_reviews_provider.dart';
import '../widgets/vendor_review_card.dart';
import '../widgets/vendor_review_filter.dart';
import '../widgets/vendor_review_filter_row.dart';
import '../widgets/vendor_review_summary_card.dart';
import '../widgets/vendor_reviews_empty_state.dart';

/// Reusable, scrollable section of the stall reviews list
/// (used inside the vendor profile page).
class VendorReviewsSection extends ConsumerStatefulWidget {
  final String? vendorId;

  const VendorReviewsSection({super.key, this.vendorId});

  @override
  ConsumerState<VendorReviewsSection> createState() =>
      _VendorReviewsSectionState();
}

class _VendorReviewsSectionState extends ConsumerState<VendorReviewsSection> {
  VendorReviewFilter _filter = VendorReviewFilter.all;

  @override
  Widget build(BuildContext context) {
    final allReviews = widget.vendorId != null
        ? ref.watch(vendorReviewsFamilyProvider(widget.vendorId!))
        : ref.watch(vendorReviewsProvider);
    final filtered = filterReviews(allReviews, _filter);

    if (allReviews.isEmpty) {
      return const VendorReviewsEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: VendorReviewSummaryCard(reviews: allReviews),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: VendorReviewFilterRow(
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
            allReviews: allReviews,
          ),
        ),
        if (filtered.isEmpty)
          VendorReviewsFilteredEmptyState(filter: _filter)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (context, idx) => const SizedBox(height: 10),
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: i == filtered.length - 1 ? 24 : 0,
              ),
              child: VendorReviewCard(review: filtered[i]),
            ),
          ),
      ],
    );
  }
}

/// Full-screen reviews page (stall owner / public stall profile).
class VendorReviewsScreen extends ConsumerStatefulWidget {
  final String? vendorId;

  const VendorReviewsScreen({super.key, this.vendorId});

  @override
  ConsumerState<VendorReviewsScreen> createState() =>
      _VendorReviewsScreenState();
}

class _VendorReviewsScreenState extends ConsumerState<VendorReviewsScreen> {
  VendorReviewFilter _filter = VendorReviewFilter.all;

  @override
  Widget build(BuildContext context) {
    final allReviews = widget.vendorId != null
        ? ref.watch(vendorReviewsFamilyProvider(widget.vendorId!))
        : ref.watch(vendorReviewsProvider);
    final filtered = filterReviews(allReviews, _filter);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppTheme.primaryGreen,
          ),
        ),
        title: Text(
          widget.vendorId != null ? 'Stall Reviews' : 'Customer Reviews',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryGreen,
          ),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: allReviews.isEmpty
          ? const VendorReviewsEmptyState()
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: VendorReviewSummaryCard(reviews: allReviews),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: VendorReviewFilterRow(
                      selected: _filter,
                      onChanged: (f) => setState(() => _filter = f),
                      allReviews: allReviews,
                    ),
                  ),
                ),
                filtered.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: VendorReviewsFilteredEmptyState(filter: _filter),
                      )
                    : SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, idx) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) => Padding(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: i == filtered.length - 1 ? 24 : 0,
                          ),
                          child: VendorReviewCard(review: filtered[i]),
                        ),
                      ),
              ],
            ),
    );
  }
}
