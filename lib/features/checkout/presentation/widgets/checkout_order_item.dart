import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';

class CheckoutOrderItem extends StatelessWidget {
  const CheckoutOrderItem({super.key, required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final unit = item.unit;
    final priceLabel = '${item.price}/$unit';
    final quantityLabel = item.quantityLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AdaptiveImage(
              item.image.isNotEmpty ? item.image : null,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              placeholder: Container(
                width: 48,
                height: 48,
                color: const Color(0xFFE5E7EB),
                child: const Icon(
                  Icons.image_rounded,
                  color: AppTheme.muted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$quantityLabel • $priceLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₱${item.total.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
