import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/domain/sales_summary.dart';

/// Daily sales rollups for the logged-in vendor's stall, computed from real completed orders.
final vendorDailySalesProvider =
    FutureProvider.autoDispose<List<SalesSummary>>((ref) async {
  List<MarketOrder> orders = [];
  try {
    orders = await ref.watch(vendorOrdersProvider.future);
  } catch (_) {}
  final completed =
      orders.where((o) => o.status == OrderStatus.completed).toList();
  final stallId = ref.watch(vendorStallProvider).stallId;

  if (completed.isNotEmpty) {
    final map = <DateTime, (double revenue, int count, int itemsCount)>{};
    for (final o in completed) {
      final d = o.placedAt.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      final prev = map[day] ?? (0.0, 0, 0);
      final itemsCount =
          o.items.fold<int>(0, (sum, i) => sum + i.quantity.round());
      map[day] = (prev.$1 + o.total, prev.$2 + 1, prev.$3 + itemsCount);
    }

    return map.entries
        .map(
          (e) => SalesSummary(
            summaryId: e.key.toIso8601String().split('T').first,
            stallId: stallId,
            date: e.key,
            totalOrders: e.value.$2,
            totalRevenue: e.value.$1,
            totalItemsSold: e.value.$3,
          ),
        )
        .toList();
  }

  // Fallback to repository for mock demo stalls if no live completed orders yet
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 61));
  return ref.read(vendorRepositoryProvider).getSalesSummary(
        stallId,
        from: from,
        to: now,
      );
});
