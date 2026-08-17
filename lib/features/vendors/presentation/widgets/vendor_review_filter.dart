import 'package:palengkego/features/vendors/domain/vendor_review.dart';

/// Star-rating filter for the reviews list.
enum VendorReviewFilter { all, five, four, three, two, one }

List<VendorReview> filterReviews(
  List<VendorReview> all,
  VendorReviewFilter filter,
) {
  switch (filter) {
    case VendorReviewFilter.five:
      return all.where((r) => r.rating.round() == 5).toList();
    case VendorReviewFilter.four:
      return all.where((r) => r.rating.round() == 4).toList();
    case VendorReviewFilter.three:
      return all.where((r) => r.rating.round() == 3).toList();
    case VendorReviewFilter.two:
      return all.where((r) => r.rating.round() == 2).toList();
    case VendorReviewFilter.one:
      return all.where((r) => r.rating.round() == 1).toList();
    case VendorReviewFilter.all:
      return all;
  }
}

int countReviews(List<VendorReview> all, VendorReviewFilter filter) =>
    filterReviews(all, filter).length;

/// Display label used by the filtered empty state.
String reviewFilterLabel(VendorReviewFilter filter) {
  switch (filter) {
    case VendorReviewFilter.five:
      return '5-star';
    case VendorReviewFilter.four:
      return '4-star';
    case VendorReviewFilter.three:
      return '3-star';
    case VendorReviewFilter.two:
      return '2-star';
    case VendorReviewFilter.one:
      return '1-star';
    case VendorReviewFilter.all:
      return '';
  }
}
