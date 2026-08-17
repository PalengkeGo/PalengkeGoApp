/// Daily sales summary for a vendor stall.
///
/// Matches the SALES_SUMMARY ERD entity.
/// Collection path: `salesSummary/{stallId}/daily/{date}` (e.g. '2025-07-02')
///
/// Written by a Cloud Function when an order reaches `completed` status.
/// Read by the Vendor Earnings screen.
class SalesSummary {
  const SalesSummary({
    required this.summaryId,
    required this.stallId,
    required this.date,
    required this.totalOrders,
    required this.totalRevenue,
    required this.totalItemsSold,
  });

  /// Firestore document ID (typically the date string, e.g. '2025-07-02').
  final String summaryId;

  /// The owning vendor's stall ID.
  final String stallId;

  /// The calendar date this summary covers.
  final DateTime date;

  /// Count of completed orders on this date.
  final int totalOrders;

  /// Total revenue in PHP for this date.
  final double totalRevenue;

  /// Total number of individual product units sold.
  final int totalItemsSold;

  Map<String, dynamic> toFirestore() {
    return {
      'stallId': stallId,
      'date': date.toIso8601String().split('T').first,
      'totalOrders': totalOrders,
      'totalRevenue': totalRevenue,
      'totalItemsSold': totalItemsSold,
    };
  }

  factory SalesSummary.fromFirestore(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return SalesSummary(
      summaryId: id,
      stallId: data['stallId'] as String? ?? '',
      date: data['date'] != null
          ? DateTime.parse(data['date'] as String)
          : DateTime.now(),
      totalOrders: data['totalOrders'] as int? ?? 0,
      totalRevenue: (data['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalItemsSold: data['totalItemsSold'] as int? ?? 0,
    );
  }
}
