import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/navigation/app_router.dart';
import 'package:palengkego/core/navigation/app_routes.dart';

import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';

import 'package:palengkego/features/orders/presentation/widgets/order_history_card.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_history_empty_state.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_history_tab_row.dart';
import 'package:palengkego/features/orders/presentation/widgets/rating_modal.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  OrderTab _selectedTab = OrderTab.all;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(orderServiceProvider);

    return ordersAsync.when(
      data: (ordersList) {
        final orders = _filteredOrders(ordersList);

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(context),
                OrderHistoryTabRow(
                  selectedTab: _selectedTab,
                  onTabChanged: (tab) => setState(() => _selectedTab = tab),
                ),
                const Divider(height: 1, color: Color(0xFFE8ECE9)),
                Expanded(
                  child: orders.isEmpty
                      ? OrderHistoryEmptyState(currentTab: _selectedTab)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                          itemCount: orders.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) => OrderHistoryCard(
                            order: orders[index],
                            onPrimaryAction: () =>
                                _handlePrimaryAction(context, orders[index]),
                            onSecondaryAction:
                                orders[index].status == OrderStatus.completed
                                ? () => _handleSecondaryAction(
                                    context,
                                    orders[index],
                                  )
                                : null,
                            onTertiaryAction:
                                orders[index].status == OrderStatus.completed
                                ? () => RatingModal.show(context, orders[index])
                                : null,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Colors.white,
        body: AsyncLoadingView(color: AppTheme.primaryGreen),
      ),
      error: (err, stack) => const Scaffold(
        backgroundColor: Colors.white,
        body: AsyncErrorView(message: 'Error loading orders'),
      ),
    );
  }

  List<MarketOrder> _filteredOrders(List<MarketOrder> orders) {
    switch (_selectedTab) {
      case OrderTab.all:
        return orders;
      case OrderTab.active:
        return orders
            .where(
              (order) =>
                  order.status == OrderStatus.pending ||
                  order.status == OrderStatus.confirmed ||
                  order.status == OrderStatus.preparing ||
                  order.status == OrderStatus.ready,
            )
            .toList();
      case OrderTab.completed:
        return orders
            .where((order) => order.status == OrderStatus.completed)
            .toList();
      case OrderTab.cancelled:
        return orders
            .where((order) => order.status == OrderStatus.cancelled)
            .toList();
    }
  }

  Widget _header(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Center(
        child: Text(
          'My Orders',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF202020),
          ),
        ),
      ),
    );
  }

  void _handlePrimaryAction(BuildContext context, MarketOrder order) {
    if (order.status == OrderStatus.confirmed ||
        order.status == OrderStatus.pending ||
        order.status == OrderStatus.preparing ||
        order.status == OrderStatus.ready) {
      // Navigate to Track Order screen for active orders
      Navigator.of(context).pushNamed(
        AppRoutes.trackOrder,
        arguments: TrackOrderRouteArgs(order: order, isPickup: order.isPickup),
      );
      return;
    }

    _showOrderDetails(context, order);
  }

  void _handleSecondaryAction(BuildContext context, MarketOrder order) {
    final cartNotifier = ref.read(cartItemsProvider.notifier);
    for (final item in order.items) {
      cartNotifier.addToCart(
        CartItem(
          productId: item.productId,
          vendorName: order.vendorName,
          productName: item.productName,
          price: item.unitPrice,
          unit: item.unit,
          image: item.image,
          quantity: item.quantity,
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${order.vendorName} items added back to cart.')),
    );
    // Cart is no longer a tab — push the cart screen
    Navigator.of(context).pushNamed(AppRoutes.cart);
  }

  void _showOrderDetails(BuildContext context, MarketOrder order) {
    Navigator.of(context).pushNamed(
      AppRoutes.orderDetails,
      arguments: OrderDetailsRouteArgs(order: order),
    );
  }
}
