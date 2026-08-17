import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class CheckoutSummaryRow extends StatelessWidget {
  const CheckoutSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.highlighted = false,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool highlighted;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: isBold ? AppTheme.primaryGreen : AppTheme.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: (highlighted || isBold)
                ? AppTheme.primaryGreen
                : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
