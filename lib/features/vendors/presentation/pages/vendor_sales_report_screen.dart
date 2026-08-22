import 'dart:isolate';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/vendors/application/detailed_sales_report_export_service.dart';
import 'package:palengkego/core/utils/file_export_util.dart';
import 'package:palengkego/core/widgets/empty_state.dart';

import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';

class VendorSalesReportScreen extends ConsumerStatefulWidget {
  const VendorSalesReportScreen({super.key});

  @override
  ConsumerState<VendorSalesReportScreen> createState() =>
      _VendorSalesReportScreenState();
}

class _VendorSalesReportScreenState
    extends ConsumerState<VendorSalesReportScreen> {
  bool _isExporting = false;

  List<MarketOrder> _completedOrders() {
    final vendorOrders = ref.read(vendorOrdersProvider).value ?? [];
    return vendorOrders
        .where((o) => o.status == OrderStatus.completed)
        .toList();
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final orders = _completedOrders();
      final now = DateTime.now();
      final stallName = ref.read(vendorStallProvider).name;
      final bytes = await Isolate.run(() => DetailedSalesReportExportService.buildPdf(
        orders,
        now,
        stallName,
      ));
      final filename = DetailedSalesReportExportService.buildFilename(
        now,
        stallName,
      );

      final path = await FileExportUtil.saveFileToPublicDirectory(
        filename: '$filename.pdf',
        bytes: bytes,
      );

      if (mounted) {
        AppServices.showSnackBar(
          'Sales report saved directly to: $path',
          backgroundColor: AppTheme.primaryGreen,
        );
      }
    } catch (e) {
      if (mounted) AppServices.showError('Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);
    try {
      final orders = _completedOrders();
      final now = DateTime.now();
      final stallName = ref.read(vendorStallProvider).name;
      final bytes = await Isolate.run(() => DetailedSalesReportExportService.buildExcel(
        orders,
        now,
        stallName,
      ));
      final filename = DetailedSalesReportExportService.buildFilename(
        now,
        stallName,
      );

      final path = await FileExportUtil.saveFileToPublicDirectory(
        filename: '$filename.xlsx',
        bytes: bytes,
      );

      if (mounted) {
        AppServices.showSnackBar(
          'Excel report saved directly to: $path',
          backgroundColor: AppTheme.primaryGreen,
        );
      }
    } catch (e) {
      if (mounted) AppServices.showError('Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref
        .watch(vendorOrdersProvider)
        .whenData(
          (orders) =>
              orders.where((o) => o.status == OrderStatus.completed).toList(),
        );

    return AuthGuard(
      allowedRoles: {UserRole.vendor},
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Detailed Sales Report',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppTheme.primaryGreen),
        ),
        body: Column(
          children: [
            _buildExportActions(),
            Expanded(
              child: ordersAsync.when(
                data: (orders) => orders.isEmpty
                    ? const EmptyState(title: 'No completed transactions yet.')
                    : ListView.builder(
                        itemCount: orders.length,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return _buildTransactionCard(order);
                        },
                      ),
                loading: () => const AsyncLoadingView(),
                error: (err, stack) =>
                    const AsyncErrorView(message: 'Error loading report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF9FAFB),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportPdf,
              icon: const Icon(
                Icons.picture_as_pdf,
                color: Colors.white,
                size: 20,
              ),
              label: const Text('Export PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportExcel,
              icon: const Icon(
                Icons.table_chart,
                color: Colors.white,
                size: 20,
              ),
              label: const Text('Export Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(MarketOrder order) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final formatCurrency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final itemsStr = order.items
        .map((i) => '${i.quantity}x ${i.productName}')
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                Text(
                  dateFormat.format(order.placedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _buildDetailRow('Customer:', order.customerName),
            _buildDetailRow(
              'Type:',
              order.fulfillmentMethod.name.toUpperCase(),
            ),
            _buildDetailRow('Payment:', order.paymentStatus.name.toUpperCase()),
            const SizedBox(height: 8),
            const Text(
              'Items:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            Text(itemsStr, style: const TextStyle(fontSize: 14)),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  formatCurrency.format(order.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
