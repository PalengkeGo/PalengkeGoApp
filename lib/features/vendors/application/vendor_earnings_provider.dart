import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/domain/sales_summary.dart';

/// Daily sales rollups for the logged-in vendor's stall, covering the last
/// 62 days (enough for a 30-day view plus its previous-period comparison).
///
/// The `salesSummary` docs are written exclusively by the trusted backend
/// when an order completes — the earnings screen never fabricates figures.
/// Mock mode serves the seeded demo summaries from the mock repository.
final vendorDailySalesProvider =
    FutureProvider.autoDispose<List<SalesSummary>>((ref) async {
  final stall = ref.watch(vendorStallProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 61));
  return ref.read(vendorRepositoryProvider).getSalesSummary(
        stall.stallId,
        from: from,
        to: now,
      );
});
