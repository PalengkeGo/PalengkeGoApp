import 'package:flutter/material.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';

/// Colored status pill shared by vendor order screens.
class VendorOrderStatusBadge extends StatelessWidget {
  const VendorOrderStatusBadge({
    super.key,
    required this.status,
    this.fontSize = 10,
    this.horizontalPadding = 8,
    this.verticalPadding = 4,
  });

  final OrderStatus status;
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final statusColor = colorForStatus(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: statusColor,
        ),
      ),
    );
  }

  static Color colorForStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppTheme.starRating;
      case OrderStatus.preparing:
        return const Color(0xFF3B82F6);
      case OrderStatus.ready:
        return AppTheme.statusOpen;
      case OrderStatus.completed:
        return AppTheme.statusOpen;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return const Color(0xFFEF4444);
      default:
        return AppTheme.textSecondary;
    }
  }
}
