import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_screen_header.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_details_cards.dart';
import 'package:palengkego/features/orders/presentation/widgets/tracking_map_preview.dart';
import 'package:palengkego/features/vendors/presentation/widgets/vendor_order_actions.dart';
import 'package:palengkego/features/vendors/presentation/widgets/vendor_order_header_card.dart';
import 'package:palengkego/features/vendors/presentation/widgets/vendor_order_instructions_card.dart';
import 'package:palengkego/features/vendors/presentation/widgets/vendor_order_items_card.dart';

class VendorOrderDetailsScreen extends ConsumerWidget {
  const VendorOrderDetailsScreen({super.key, required this.order});

  final MarketOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthGuard(
      allowedRoles: {UserRole.vendor},
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const AppScreenHeader(title: 'Order Details'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrackingMapPreview(order: order),
                      OrderDetailsAddressCard(order: order),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            VendorOrderHeaderCard(order: order),
                            const SizedBox(height: 24),
                            VendorOrderItemsCard(order: order),
                            const SizedBox(height: 24),
                            const Text(
                              'Special Instructions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 12),
                            VendorOrderInstructionsCard(order: order),
                            const SizedBox(height: 24),
                            VendorOrderActions(order: order),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
