import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_sales_report_screen.dart';

class DashboardSalesCard extends ConsumerWidget {
  const DashboardSalesCard({super.key});

  Widget _buildStatBox({
    required String label,
    required String value,
    required Color color,
    required Color textColor,
    required Widget iconBadge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              iconBadge,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(vendorOrdersProvider);
    final orders = ordersAsync.value ?? [];

    final pendingOrdersCount = orders
        .where(
          (o) =>
              o.status == OrderStatus.pending ||
              o.status == OrderStatus.preparing,
        )
        .length;

    final completedOrdersCount = orders
        .where((o) => o.status == OrderStatus.completed)
        .length;

    final todaysSales = orders
        .where((o) => o.status == OrderStatus.completed)
        .fold<double>(0.0, (sum, o) => sum + o.total);

    final currencyFormatter = NumberFormat.currency(
      symbol: '₱',
      decimalDigits: 2,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Today\'s Sales',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    PageTransitions.slideFromRight(
                      const VendorSalesReportScreen(),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Text(
                      'Report',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                currencyFormatter.format(todaysSales),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildStatBox(
                    label: 'Pending',
                    value: pendingOrdersCount == 1
                        ? '1 Order'
                        : '$pendingOrdersCount Orders',
                    color: const Color(0xFFFFF7ED),
                    textColor: const Color(0xFF9A3412),
                    iconBadge: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEDD5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        size: 22,
                        color: Color(0xFFC2410C),
                      ),
                    ),
                    onTap: () {
                      ref.read(vendorOrdersTabIndexProvider.notifier).select(0);
                      ref
                          .read(vendorDashboardTabIndexProvider.notifier)
                          .select(1);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    label: 'Completed',
                    value: completedOrdersCount == 1
                        ? '1 Order'
                        : '$completedOrdersCount Orders',
                    color: const Color(0xFFF0FDF4),
                    textColor: const Color(0xFF166534),
                    iconBadge: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 24,
                        color: Color(0xFF166534),
                      ),
                    ),
                    onTap: () {
                      ref.read(vendorOrdersTabIndexProvider.notifier).select(1);
                      ref
                          .read(vendorDashboardTabIndexProvider.notifier)
                          .select(1);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
