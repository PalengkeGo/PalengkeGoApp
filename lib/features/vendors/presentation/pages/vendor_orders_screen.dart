import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:palengkego/core/widgets/empty_state.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_order_details_screen.dart';
import 'package:palengkego/features/vendors/presentation/widgets/vendor_order_status_badge.dart';

import '../widgets/vendor_screen_header.dart';

/// Vendor Orders Screen
/// Shows all orders with tabs for All, Pending, Preparing, and Ready.
class VendorOrdersScreen extends ConsumerStatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  ConsumerState<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends ConsumerState<VendorOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      allowedRoles: {UserRole.vendor},
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              const VendorScreenHeader(title: 'Orders'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryGreen,
                  unselectedLabelColor: AppTheme.muted,
                  indicatorColor: AppTheme.primaryGreen,
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'Active'),
                    Tab(text: 'History'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    _VendorOrdersTab(isHistory: false),
                    _VendorOrdersTab(isHistory: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorOrdersTab extends ConsumerWidget {
  const _VendorOrdersTab({required this.isHistory});

  final bool isHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(vendorOrdersProvider);

    return ordersAsync.when(
      data: (allOrders) {
        final orders = allOrders.where((order) {
          final terminal =
              order.status == OrderStatus.completed ||
              order.status == OrderStatus.cancelled ||
              order.status == OrderStatus.rejected;
          return isHistory ? terminal : !terminal;
        }).toList();

        if (orders.isEmpty) {
          return const EmptyState(
            title: 'No orders in this tab yet.',
            titleStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final formatCurrency = NumberFormat.currency(
              symbol: '₱',
              decimalDigits: 2,
            );
            final deliveryMode = order.isPickup
                ? 'Pick-Up'
                : (order.isPriority
                      ? 'Priority Delivery'
                      : 'Standard Delivery');
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  PageTransitions.slideFromRight(
                    VendorOrderDetailsScreen(order: order),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            VendorOrderStatusBadge(
                              status: order.status,
                              isPickup: order.isPickup,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              deliveryMode,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    order.isPriority && !order.isPickup
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                color: order.isPriority && !order.isPickup
                                    ? AppTheme.warning
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          formatCurrency.format(order.total),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Order ${order.id}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            if (order.isPriority) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      size: 12,
                                      color: AppTheme.warning,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'PRIORITY',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          DateFormat('MMM d, hh:mm a').format(order.placedAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.customerName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          order.isPickup
                              ? Icons.storefront_outlined
                              : Icons.location_on_outlined,
                          size: 14,
                          color: order.isPickup
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            order.isPickup
                                ? 'Store Pickup (Customer will pick up at stall)'
                                : (order.deliveryAddress?.isNotEmpty == true
                                    ? order.deliveryAddress!
                                    : 'San Felipe, Naga City'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: order.isPickup
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFF475569),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: AppTheme.border),
                    Text(
                      'Items (${order.items.length})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 2),
                        child: Text(
                          '• ${item.quantityLabel} ${item.productName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    if (order.notes != null && order.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFEF3C7)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.note_alt_outlined,
                              size: 16,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Special Instructions:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.warning,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    order.notes!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF78350F),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (!isHistory) _VendorOrderActions(order: order),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const AsyncLoadingView(),
      error: (error, stack) => AsyncErrorView(message: 'Error: $error'),
    );
  }
}

class _VendorOrderActions extends ConsumerWidget {
  const _VendorOrderActions({required this.order});

  final MarketOrder order;

  /// Runs a vendor action, surfacing any typed [OrderFailure] to the user
  /// instead of showing a misleading success snackbar.
  Future<void> _runAction(
    BuildContext context,
    Future<void> action, {
    required String successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action;
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } on OrderFailure catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFB3261E),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(vendorOrdersProvider.notifier);

    if (order.status == OrderStatus.pending) {
      return Row(
        children: [
          Expanded(
            child: _buildActionButton(
              label: 'Reject',
              isPrimary: false,
              textColor: const Color(0xFFEF4444),
              onTap: () => _runAction(
                context,
                notifier.rejectOrder(order.id),
                successMessage: 'Order ${order.id} was rejected.',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              label: 'Accept',
              isPrimary: true,
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final mins = await showDialog<int>(
                  context: context,
                  builder: (ctx) {
                    final controller = TextEditingController(text: '20');
                    return AlertDialog(
                      title: const Text(
                        'Accept Order & Set Prep Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enter estimated preparation time in minutes:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            decoration: appInputDecoration(
                              suffixText: 'mins',
                              focusedBorderWidth: 2,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(
                            ctx,
                            int.tryParse(controller.text) ?? 20,
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
                if (mins != null) {
                  try {
                    await notifier.updateEstimatedReadyTime(
                      order.id,
                      DateTime.now().add(Duration(minutes: mins)),
                      OrderStatus.preparing,
                    );
                    if (!context.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Order accepted! Prep time set to $mins mins.',
                        ),
                      ),
                    );
                  } on OrderFailure catch (e) {
                    if (!context.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(e.message),
                        backgroundColor: const Color(0xFFB3261E),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      );
    }

    if (order.status == OrderStatus.preparing) {
      return Row(
        children: [
          Expanded(
            child: _buildActionButton(
              label: 'Edit Time',
              isPrimary: false,
              backgroundColor: AppTheme.surfaceContainerLow,
              textColor: AppTheme.textSecondary,
              icon: Icons.access_time_outlined,
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final mins = await showDialog<int>(
                  context: context,
                  builder: (ctx) {
                    final controller = TextEditingController(text: '20');
                    return AlertDialog(
                      title: const Text(
                        'Estimated Prep Time (mins)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: appInputDecoration(focusedBorderWidth: 2),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(
                            ctx,
                            int.tryParse(controller.text) ?? 20,
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    );
                  },
                );
                if (mins != null) {
                  try {
                    await notifier.updateEstimatedReadyTime(
                      order.id,
                      DateTime.now().add(Duration(minutes: mins)),
                      OrderStatus.preparing,
                    );
                    if (!context.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Prep time updated to $mins mins.'),
                      ),
                    );
                  } on OrderFailure catch (e) {
                    if (!context.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(e.message),
                        backgroundColor: const Color(0xFFB3261E),
                      ),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              label: 'Mark Ready',
              isPrimary: false,
              backgroundColor: AppTheme.surfaceContainerLow,
              textColor: AppTheme.textSecondary,
              icon: Icons.inventory_2_outlined,
              onTap: () => _runAction(
                context,
                notifier.markOrderReady(order.id),
                successMessage:
                    'Order ${order.id} is ready for pickup or dispatch.',
              ),
            ),
          ),
        ],
      );
    }

    if (order.status == OrderStatus.ready) {
      return SizedBox(
        width: double.infinity,
        child: _buildActionButton(
          label: order.isPickup ? 'Mark as Picked Up' : 'Dispatch for Delivery',
          isPrimary: true,
          icon: order.isPickup
              ? Icons.check_circle_outline
              : Icons.local_shipping_outlined,
          onTap: () => _runAction(
            context,
            order.isPickup
                ? notifier.completeOrder(order.id)
                : notifier.markOrderOutForDelivery(order.id),
            successMessage: order.isPickup
                ? 'Order ${order.id} has been picked up.'
                : 'Order ${order.id} is out for delivery.',
          ),
        ),
      );
    }

    if (order.status == OrderStatus.outForDelivery) {
      return SizedBox(
        width: double.infinity,
        child: _buildActionButton(
          label: 'Mark as Delivered',
          isPrimary: true,
          icon: Icons.check_circle_outline,
          onTap: () => _runAction(
            context,
            notifier.completeOrder(order.id),
            successMessage: 'Order ${order.id} has been delivered.',
          ),
        ),
      );
    }

    return const SizedBox.shrink(); // No actions for completed or cancelled
  }

  Widget _buildActionButton({
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppTheme.primaryGreen
              : (backgroundColor ?? Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: isPrimary ? null : Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: icon != null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: textColor ?? AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor ?? AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isPrimary
                        ? Colors.white
                        : (textColor ?? AppTheme.primaryGreen),
                  ),
                ),
        ),
      ),
    );
  }
}
