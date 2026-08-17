import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';

/// Header row for the order details screen: back button + order number.
/// Falls back to the main tab when there is nothing to pop.
class OrderDetailsHeader extends StatelessWidget {
  final String orderId;

  const OrderDetailsHeader({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.of(context).pushReplacementNamed(AppRoutes.main);
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Order #$orderId',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
