import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';

class CartItemCard extends StatelessWidget {
  const CartItemCard({
    super.key,
    required this.item,
    required this.onToggleSelect,
    required this.onQuantityChange,
    required this.onDelete,
  });

  final CartItem item;
  final VoidCallback onToggleSelect;
  final ValueChanged<double> onQuantityChange;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: item.selected,
              activeColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (_) => onToggleSelect(),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AdaptiveImage(
                item.image.isNotEmpty ? item.image : null,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                placeholder: const Icon(
                  Icons.image_outlined,
                  size: 28,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.quantityLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '₱${item.total.toStringAsFixed(0)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _QuantityStepper(
                      quantity: item.quantity,
                      maxQuantity: item.stockQuantity.toDouble(),
                      unit: item.unit,
                      onChanged: (delta) {
                        onQuantityChange(delta);
                      },
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _stepKgQuantity(double current, bool isIncrement, double maxWeight) {
  final double whole = current.floorToDouble();
  final double fraction = current - whole;

  if (isIncrement) {
    if (fraction < 0.124) {
      return (whole + 0.125).clamp(0.125, maxWeight);
    } else if (fraction < 0.249) {
      return (whole + 0.25).clamp(0.125, maxWeight);
    } else if (fraction < 0.499) {
      return (whole + 0.5).clamp(0.125, maxWeight);
    } else if (fraction < 0.749) {
      return (whole + 0.75).clamp(0.125, maxWeight);
    } else {
      return (whole + 1.0).clamp(0.125, maxWeight);
    }
  } else {
    if (fraction > 0.751) {
      return (whole + 0.75).clamp(0.125, maxWeight);
    } else if (fraction > 0.501) {
      return (whole + 0.5).clamp(0.125, maxWeight);
    } else if (fraction > 0.251) {
      return (whole + 0.25).clamp(0.125, maxWeight);
    } else if (fraction > 0.126) {
      return (whole + 0.125).clamp(0.125, maxWeight);
    } else if (fraction > 0.001) {
      return whole.clamp(0.0, maxWeight);
    } else {
      if (whole >= 1.0) {
        return (whole - 1.0 + 0.75).clamp(0.125, maxWeight);
      } else {
        return 0.0;
      }
    }
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.maxQuantity,
    required this.unit,
    required this.onChanged,
  });

  final double quantity;
  final double maxQuantity;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (unit == 'kg') {
                onChanged(_stepKgQuantity(quantity, false, maxQuantity));
              } else {
                onChanged((quantity - 1.0).clamp(0.0, maxQuantity));
              }
            },
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              child: const Icon(Icons.remove_rounded, size: 16),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            height: 30,
            alignment: Alignment.center,
            child: Text(
              unit == 'kg'
                  ? CartItem(
                      productId: '',
                      vendorName: '',
                      productName: '',
                      price: 0,
                      image: '',
                      quantity: quantity,
                      unit: 'kg',
                    ).quantityLabel.replaceAll(' kg', '')
                  : quantity.toInt().toString(),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF101828),
              ),
            ),
          ),
          GestureDetector(
            onTap: quantity < maxQuantity
                ? () {
                    if (unit == 'kg') {
                      onChanged(_stepKgQuantity(quantity, true, maxQuantity));
                    } else {
                      onChanged((quantity + 1.0).clamp(1.0, maxQuantity));
                    }
                  }
                : () {
                    if (!context.mounted) return;
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context).cartMaxStock,
                        ),
                      ),
                    );
                  },
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: quantity < maxQuantity
                    ? AppTheme.primaryGreen
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
