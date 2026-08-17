import 'package:flutter/material.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_summary_row.dart';

/// White card with subtotal / fees / total breakdown for an order.
class OrderDetailsSummaryCard extends StatelessWidget {
  final MarketOrder order;

  const OrderDetailsSummaryCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final subtotalAmount = order.subtotal;
    final deliveryFeeAmount = order.deliveryFee;
    final serviceFeeAmount = order.serviceFee;
    final totalAmount = order.total;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            OrderSummaryRow(
              label: 'Subtotal',
              value: '₱${subtotalAmount.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 12),
            OrderSummaryRow(
              label: 'Delivery Fee',
              value: '₱${deliveryFeeAmount.toStringAsFixed(2)}',
            ),
            if (order.isPriority) ...[
              const SizedBox(height: 12),
              OrderSummaryRow(
                label: 'Priority Delivery Fee',
                value: '₱${order.priorityFee.toStringAsFixed(2)}',
              ),
            ],
            const SizedBox(height: 12),
            OrderSummaryRow(
              label: 'Service Fee',
              value: '₱${serviceFeeAmount.toStringAsFixed(2)}',
            ),
            const Divider(height: 24, color: Color(0xFFE5E7EB)),
            OrderSummaryRow(
              label: 'Total',
              value: '₱${totalAmount.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }
}
