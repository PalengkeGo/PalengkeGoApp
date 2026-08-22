import 'package:palengkego/core/utils/money.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import '../../domain/market_order.dart';
import '../../domain/order_status.dart';

class OrderHistoryCard extends StatelessWidget {
  final MarketOrder order;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final VoidCallback? onTertiaryAction;

  const OrderHistoryCard({
    super.key,
    required this.order,
    required this.onPrimaryAction,
    this.onSecondaryAction,
    this.onTertiaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(order.status);
    final secondaryAction = _secondaryActionLabel(order.status);
    final primaryAction = _primaryActionLabel(order.status);
    final tertiaryAction = order.status == OrderStatus.completed
        ? 'Rate'
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECE9)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(16, 24, 40, 0.04),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onPrimaryAction,
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AdaptiveImage(
                    order.vendorImage,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      width: 40,
                      height: 40,
                      color: const Color(0xFFE7ECE9),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 18,
                        color: Color(0xFF8A9A95),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.vendorName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF23342F),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Order ${order.id}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8EB0A3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusStyle.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusStyle.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFEDEFEA)),
          const SizedBox(height: 10),
          Text(
            _itemsPreview(order),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF89A89D),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _formatDateTime(order.placedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9AB4AA),
                  ),
                ),
              ),
              Text(
                'PHP ${pesoOf(order.total)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF264A3D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (tertiaryAction != null && onTertiaryAction != null) ...[
                Expanded(
                  child: _actionButton(
                    label: tertiaryAction,
                    onTap: onTertiaryAction!,
                    trailingIcon: Icons.star_outline_rounded,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (secondaryAction != null && onSecondaryAction != null) ...[
                Expanded(
                  child: _actionButton(
                    label: secondaryAction,
                    onTap: onSecondaryAction!,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _actionButton(
                  label: primaryAction,
                  filled: secondaryAction == null,
                  trailingIcon:
                      (order.status == OrderStatus.confirmed ||
                          order.status == OrderStatus.pending)
                      ? (order.isPickup
                            ? Icons.storefront_outlined
                            : Icons.local_shipping_outlined)
                      : null,
                  onTap: onPrimaryAction,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onTap,
    bool filled = false,
    IconData? trailingIcon,
  }) {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: filled ? const Color(0xFFF0F3F0) : Colors.white,
          foregroundColor: const Color(0xFF35554A),
          side: BorderSide(
            color: filled ? const Color(0xFFF0F3F0) : const Color(0xFFDDE5E0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 5),
              Icon(trailingIcon, size: 13),
            ] else if (filled) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios_rounded, size: 10),
            ],
          ],
        ),
      ),
    );
  }

  _StatusStyle _statusStyle(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const _StatusStyle(
          background: Color(0xFFFFF4CC),
          foreground: Color(0xFFC78800),
        );
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
      case OrderStatus.ready:
      case OrderStatus.outForDelivery:
        return const _StatusStyle(
          background: Color(0xFFE8F6E8),
          foreground: Color(0xFF6DA566),
        );
      case OrderStatus.completed:
        return const _StatusStyle(
          background: Color(0xFFE8F6E8),
          foreground: Color(0xFF6DA566),
        );
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return const _StatusStyle(
          background: Color(0xFFFFE5E5),
          foreground: Color(0xFFEA7171),
        );
    }
  }

  String _itemsPreview(MarketOrder order) {
    return order.items
        .map((item) => '${item.productName}(${item.quantityLabel})')
        .join(', ');
  }

  String _primaryActionLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
      case OrderStatus.ready:
      case OrderStatus.outForDelivery:
      case OrderStatus.pending:
        return 'Track Order';
      case OrderStatus.completed:
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return 'View Details';
    }
  }

  String? _secondaryActionLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return 'Reorder';
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
      case OrderStatus.ready:
      case OrderStatus.outForDelivery:
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return null;
    }
  }

  String _formatDateTime(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';

    return '${months[value.month - 1]} ${value.day}, ${value.year} • '
        '$hour:$minute $period';
  }
}

class _StatusStyle {
  final Color background;
  final Color foreground;

  const _StatusStyle({required this.background, required this.foreground});
}