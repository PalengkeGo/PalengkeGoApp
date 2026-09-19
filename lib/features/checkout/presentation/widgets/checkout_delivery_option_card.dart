import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/utils/money.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';

class CheckoutDeliveryOptionCard extends ConsumerWidget {
  const CheckoutDeliveryOptionCard({
    super.key,
    required this.isPrioritySelected,
    required this.onOptionChanged,
  });

  final bool isPrioritySelected;
  final ValueChanged<bool> onOptionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveryAddress = ref.watch(preferencesProvider).deliveryAddress;
    final standardFee = FeeConfig.computeDeliveryFee(
      lat: deliveryAddress.latitude,
      lng: deliveryAddress.longitude,
      isPriority: false,
    );
    final priorityTotal = FeeConfig.computeDeliveryFee(
      lat: deliveryAddress.latitude,
      lng: deliveryAddress.longitude,
      isPriority: true,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Speed Option',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Standard Delivery Card
            Expanded(
              child: GestureDetector(
                onTap: () => onOptionChanged(false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: !isPrioritySelected
                        ? const Color(0xFFF0FDF4)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: !isPrioritySelected
                          ? AppTheme.primaryGreen
                          : AppTheme.border,
                      width: !isPrioritySelected ? 2 : 1,
                    ),
                    boxShadow: !isPrioritySelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(
                                alpha: 0.08,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 22,
                            color: !isPrioritySelected
                                ? AppTheme.primaryGreen
                                : AppTheme.textSecondary,
                          ),
                          if (!isPrioritySelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: AppTheme.primaryGreen,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Standard',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '25 – 40 mins',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pesoOf(standardFee),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Priority Delivery Card
            Expanded(
              child: GestureDetector(
                onTap: () => onOptionChanged(true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isPrioritySelected
                        ? const Color(0xFFFFFBEB)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isPrioritySelected
                          ? const Color(0xFFD97706)
                          : AppTheme.border,
                      width: isPrioritySelected ? 2 : 1,
                    ),
                    boxShadow: isPrioritySelected
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFD97706,
                              ).withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 22,
                                color: isPrioritySelected
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFFF59E0B),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'FAST',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isPrioritySelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: Color(0xFFD97706),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Priority',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '15 – 25 mins',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            pesoOf(priorityTotal),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '(+₱29)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
