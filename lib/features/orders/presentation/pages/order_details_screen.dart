import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_details_items_list.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_details_cards.dart';
import 'package:palengkego/features/orders/presentation/widgets/tracking_map_preview.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_details_header.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_details_items_header.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_details_summary_card.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_details_stall_actions.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_details_cancel_bar.dart';
import 'package:palengkego/features/orders/presentation/widgets/order_refund_section.dart';
import 'package:palengkego/features/orders/presentation/widgets/cancel_orders_dialog.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/profile/application/blocked_vendors_provider.dart';
import 'package:palengkego/features/vendors/presentation/widgets/block_vendor_dialog.dart';
import 'package:palengkego/features/vendors/presentation/widgets/report_vendor_dialog.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final MarketOrder order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  Timer? _cancelTimer;
  late MarketOrder _order;
  Duration _timeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _startCancelTimer();
  }

  void _startCancelTimer() {
    final cancelUntil = _order.placedAt.add(FeeConfig.cancelWindow);
    _updateTimeRemaining(cancelUntil);

    if (_timeRemaining > Duration.zero) {
      _cancelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateTimeRemaining(cancelUntil);
        if (_timeRemaining <= Duration.zero) {
          timer.cancel();
          _autoCancelIfNeeded();
        }
      });
    } else {
      _autoCancelIfNeeded();
    }
  }

  Future<void> _autoCancelIfNeeded() async {
    final currentOrder = ref
        .read(orderServiceProvider)
        .value
        ?.firstWhere((o) => o.id == _order.id, orElse: () => _order);

    if (currentOrder != null && currentOrder.status == OrderStatus.pending) {
      try {
        await ref
            .read(orderServiceProvider.notifier)
            .cancelOrder(
              _order.id,
              now: _order.placedAt.add(FeeConfig.cancelWindow),
            );
        if (!mounted) return;
        AppServices.showSnackBar('Order automatically cancelled (timeout).');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((route) {
            return route.settings.name != null &&
                route.settings.name != AppRoutes.orderDetails &&
                route.settings.name != AppRoutes.trackOrder;
          });
        } else {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
        }
      } on OrderFailure {
        // Window already expired server-side — leave the order untouched.
      }
    }
  }

  void _updateTimeRemaining(DateTime cancelUntil) {
    final remaining = cancelUntil.difference(DateTime.now());
    if (mounted) {
      setState(() {
        _timeRemaining = remaining > Duration.zero ? remaining : Duration.zero;
      });
    }
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  String _getStatusDescription(MarketOrder order) {
    if (order.status == OrderStatus.completed) {
      return 'Delivered and completed successfully';
    } else if (order.status == OrderStatus.cancelled) {
      return 'This order has been cancelled';
    } else if (order.status == OrderStatus.confirmed) {
      return 'Confirmed by stall holder';
    } else if (order.status == OrderStatus.preparing) {
      return 'Stall Holder is preparing your items';
    } else if (order.status == OrderStatus.ready) {
      return 'Your order is ready';
    } else {
      return 'Waiting for stall holder confirmation';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(orderServiceProvider);

    return ordersAsync.when(
      data: (orders) {
        final order = orders.firstWhere(
          (o) => o.id == _order.id,
          orElse: () => _order,
        );
        return Scaffold(
          backgroundColor: AppTheme.surface,
          bottomNavigationBar:
              (order.status == OrderStatus.pending &&
                  _timeRemaining > Duration.zero)
              ? OrderDetailsCancelBar(
                  timeRemaining: _timeRemaining,
                  onPressed: () {
                    _showCancelDialog();
                  },
                )
              : null,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: OrderDetailsHeader(orderId: order.id),
                ),

                // Map Preview
                SliverToBoxAdapter(child: TrackingMapPreview(order: order)),

                // Status Timeline Bento Section
                SliverToBoxAdapter(
                  child: OrderDetailsStatusCard(
                    order: order,
                    statusDescription: _getStatusDescription(order),
                  ),
                ),

                // Estimated Arrival / Pickup Ready
                SliverToBoxAdapter(
                  child: OrderDetailsArrivalCard(order: order),
                ),

                // Delivery Address
                SliverToBoxAdapter(
                  child: OrderDetailsAddressCard(order: order),
                ),

                // Vendor Stall Card
                SliverToBoxAdapter(child: OrderDetailsVendorCard(order: order)),

                // Items List
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OrderDetailsItemsHeader(itemCount: order.items.length),
                        OrderDetailsItemsList(items: order.items),
                      ],
                    ),
                  ),
                ),

                // Notes Card
                SliverToBoxAdapter(child: OrderDetailsNotesCard(order: order)),

                // Payment Method
                SliverToBoxAdapter(
                  child: OrderDetailsPaymentCard(order: order),
                ),

                // Order Summary
                SliverToBoxAdapter(
                  child: OrderDetailsSummaryCard(order: order),
                ),

                // Refund state + request action
                SliverToBoxAdapter(child: OrderRefundSection(order: order)),

                // History Actions
                SliverToBoxAdapter(
                  child: OrderDetailsStallActions(
                    order: order,
                    onReport: () => _showReportDialog(context),
                    onBlock: () => _showBlockDialog(context),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: AsyncLoadingView(color: AppTheme.primaryGreen)),
      error: (err, stack) =>
          const Scaffold(body: AsyncErrorView(message: 'Error loading order')),
    );
  }

  void _showReportDialog(BuildContext context) async {
    final reason = await ReportVendorDialog.show(context, 'stall holder');
    if (reason != null && reason.isNotEmpty && context.mounted) {
      AppServices.showSnackBar('Stall Holder reported successfully.');
    }
  }

  void _showBlockDialog(BuildContext context) async {
    final confirmed = await BlockVendorDialog.show(
      context,
      vendorName: widget.order.vendorName,
    );
    if (confirmed == true && context.mounted) {
      final vendorName = widget.order.vendorName;
      final stallId = widget.order.stallId;

      if (stallId != null && stallId.isNotEmpty) {
        ref.read(blockedVendorsProvider.notifier).block(stallId);
        ref.read(preferencesProvider.notifier).blockStall(stallId);
      }
      ref.read(blockedVendorsProvider.notifier).block(vendorName);
      ref.read(preferencesProvider.notifier).blockStall(vendorName);

      AppServices.showSnackBar('$vendorName has been blocked.');
      Navigator.of(context).pop();
    }
  }

  void _showCancelDialog() async {
    final orders = ref.read(orderServiceProvider).value ?? [];
    final activeOrders = orders
        .where(
          (o) =>
              o.status == OrderStatus.pending &&
              o.placedAt
                  .add(const Duration(minutes: 2))
                  .isAfter(DateTime.now()),
        )
        .toList();

    if (activeOrders.isEmpty) return;

    List<String>? idsToCancel;

    if (activeOrders.length == 1) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Cancel Order?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Are you sure you want to cancel this order? This action cannot be undone.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'No, Keep It',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Yes, Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirm == true) {
        idsToCancel = [widget.order.id];
      }
    } else {
      idsToCancel = await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => CancelOrdersDialog(
          activeOrders: activeOrders,
          currentOrderId: widget.order.id,
        ),
      );
    }

    if (idsToCancel != null && idsToCancel.isNotEmpty) {
      if (!mounted) return;

      int successCount = 0;
      String? firstFailure;
      for (final id in idsToCancel) {
        try {
          await ref.read(orderServiceProvider.notifier).cancelOrder(id);
          successCount++;
          if (id == widget.order.id) {
            _cancelTimer?.cancel();
          }
        } on OrderFailure catch (e) {
          firstFailure ??= e.message;
        }
      }

      if (!mounted) return;

      if (successCount > 0) {
        AppServices.showSnackBar(
          '$successCount order(s) cancelled successfully.',
        );
      }
      if (firstFailure != null) {
        AppServices.showSnackBar(firstFailure);
      }

      final currentOrderCancelled = idsToCancel.contains(widget.order.id);

      if (currentOrderCancelled) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((route) {
            return route.settings.name != null &&
                route.settings.name != AppRoutes.orderDetails &&
                route.settings.name != AppRoutes.trackOrder;
          });
        } else {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
        }
      }
    }
  }
}
