import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/navigation/app_router.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/widgets/app_screen_header.dart';
import 'package:palengkego/features/checkout/presentation/widgets/order_confirmation_cards.dart';
import 'package:palengkego/features/checkout/presentation/widgets/order_confirmation_payment_progress.dart';

import 'package:palengkego/features/main/presentation/pages/main_screen.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';

class OrderConfirmationScreen extends ConsumerWidget {
  final bool isPickup;
  final List<MarketOrder> orders;
  final String? address;

  const OrderConfirmationScreen({
    super.key,
    required this.isPickup,
    required this.orders,
    this.address,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenHeader(
              title: 'Order Confirmation',
              size: 32,
              titleSize: 18,
              onBack: () => Navigator.of(context).pop(),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  children: [
                    // Success icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Success message
                    Text(
                      orders.length > 1
                          ? 'Orders Placed\nSuccessfully!'
                          : 'Order Placed\nSuccessfully!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Order number
                    Text(
                      orders.length > 1
                          ? 'Order Numbers: ${orders.map((o) => o.id).join(', ')}'
                          : 'Order Number: ${orders.isNotEmpty ? orders.first.id : ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Information card
                    if (orders.length > 1)
                      OrderConfirmationMultiOrderList(
                        orders: orders,
                        isPickup: isPickup,
                        address: address,
                      )
                    else if (orders.isNotEmpty)
                      OrderConfirmationInfoCard(
                        order: orders.first,
                        isPickup: isPickup,
                        address: address,
                      ),
                    const SizedBox(height: 16),

                    // Online payment progress (only for gcash/maya/card orders)
                    const OrderConfirmationPaymentProgress(),

                    // Payment method card
                    const OrderConfirmationPaymentCard(),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (orders.length == 1) {
                          // Navigate to track order screen
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.trackOrder,
                            (route) => false,
                            arguments: TrackOrderRouteArgs(
                              order: orders.first,
                              isPickup: isPickup,
                            ),
                          );
                        } else {
                          // Fallback to active orders tab in MainScreen
                          mainTabNotifier.value = 2;
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.main,
                            (route) => false,
                            arguments: const MainRouteArgs(initialIndex: 2),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        orders.length > 1
                            ? 'View Active Orders'
                            : (isPickup ? 'Track Stall' : 'Track My Order'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        // Navigate to home
                        mainTabNotifier.value = 0;
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.main,
                          (route) => false,
                          arguments: const MainRouteArgs(initialIndex: 0),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        side: const BorderSide(color: AppTheme.primaryGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Back to Home',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
