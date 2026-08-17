/// The type of entity being reviewed.
enum ReviewType { vendor, product }

/// A single customer review for a vendor stall.
///
/// Matches the RATINGS ERD entity.
/// Collection path: `ratings/{ratingId}`
///
/// The [orderId] link enforces one-review-per-order (unique constraint in ERD)
/// and also enables "Report a user" from the order history screen.
class VendorReview {
  final String id;
  final String vendorId;
  final String customerId;
  final String customerName;
  final double rating;
  final String comment;
  final DateTime date;

  /// Links this rating to the specific order it was placed for.
  /// Unique per order — a customer can only rate a vendor once per order.
  final String? orderId;

  /// Whether the customer is reviewing the stall overall or a specific product.
  final ReviewType reviewType;

  /// Populated only when [reviewType] is [ReviewType.product].
  final String? productName;

  VendorReview({
    required this.id,
    required this.vendorId,
    required this.customerId,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.date,
    this.orderId,
    this.reviewType = ReviewType.vendor,
    this.productName,
  });
}
