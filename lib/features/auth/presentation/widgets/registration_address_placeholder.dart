import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

/// Address picker tile that opens the map-based address screen.
class RegistrationAddressPlaceholder extends StatelessWidget {
  final DeliveryAddress? selectedAddress;
  final ValueChanged<DeliveryAddress> onSelected;

  const RegistrationAddressPlaceholder({
    super.key,
    required this.selectedAddress,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(
          context,
        ).pushNamed(AppRoutes.setDeliveryAddress);
        if (result is DeliveryAddress) {
          onSelected(result);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.05),
          border: Border.all(
            color: AppTheme.primaryGreen,
            width: 1,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedAddress?.primaryAddress ??
                      'Set Your Delivery Address',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                if (selectedAddress != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    selectedAddress!.streetAddress,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AppTheme.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }
}
