import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/navigation/app_router.dart';
import 'package:palengkego/core/navigation/app_routes.dart';

import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';

class FloatingOrderProgress extends ConsumerWidget {
  const FloatingOrderProgress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOrders = ref.watch(orderServiceProvider);

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: asyncOrders.when(
        data: (orders) {
          final activeOrders = orders
              .where(
                (o) =>
                    o.status != OrderStatus.completed &&
                    o.status != OrderStatus.cancelled &&
                    o.status != OrderStatus.rejected,
              )
              .toList();

          if (activeOrders.isEmpty) return const SizedBox.shrink();

          if (activeOrders.length == 1) {
            return _SingleOrderPill(
              order: activeOrders.first,
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.orderDetails,
                arguments: OrderDetailsRouteArgs(order: activeOrders.first),
              ),
            );
          }

          // Multiple active orders → multi-order tray
          return _MultiOrderPill(orders: activeOrders);
        },
        loading: () => const SizedBox.shrink(),
        error: (err, stack) => const SizedBox.shrink(),
      ),
    );
  }
}

// ── Single order pill (unchanged visual) ─────────────────────────────────────

class _SingleOrderPill extends StatelessWidget {
  final MarketOrder order;
  final VoidCallback onTap;

  const _SingleOrderPill({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    order.vendorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.statusLabel,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ── Multi-order pill ──────────────────────────────────────────────────────────

class _MultiOrderPill extends StatelessWidget {
  final List<MarketOrder> orders;

  const _MultiOrderPill({required this.orders});

  @override
  Widget build(BuildContext context) {
    // Show up to 3 stacked initials circles
    final shown = orders.take(3).toList();

    return GestureDetector(
      onTap: () => _showOrderTray(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Stacked initials
            SizedBox(
              width: 20.0 + (shown.length - 1) * 18.0,
              height: 36,
              child: Stack(
                children: [
                  for (int i = shown.length - 1; i >= 0; i--)
                    Positioned(
                      left: i * 18.0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _avatarColor(i),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryGreen,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          shown[i].vendorName.isNotEmpty
                              ? shown[i].vendorName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${orders.length} active orders',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    orders.map((o) => o.statusLabel).toSet().join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Color _avatarColor(int index) {
    const colors = [Color(0xFF2E7D57), Color(0xFF1A5C45), Color(0xFF3A9467)];
    return colors[index % colors.length];
  }

  void _showOrderTray(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderTraySheet(orders: orders),
    );
  }
}

// ── Order tray bottom sheet ───────────────────────────────────────────────────

class _OrderTraySheet extends ConsumerStatefulWidget {
  final List<MarketOrder> orders;

  const _OrderTraySheet({required this.orders});

  @override
  ConsumerState<_OrderTraySheet> createState() => _OrderTraySheetState();
}

class _OrderTraySheetState extends ConsumerState<_OrderTraySheet> {
  late List<MarketOrder> _orders;

  @override
  void initState() {
    super.initState();
    _orders = List.from(widget.orders);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(orderServiceProvider, (previous, next) {
      if (next is AsyncData) {
        final updatedOrders = next.value!
            .where(
              (o) =>
                  o.status != OrderStatus.completed &&
                  o.status != OrderStatus.cancelled &&
                  o.status != OrderStatus.rejected,
            )
            .toList();

        if (mounted) {
          setState(() {
            _orders = updatedOrders;
          });
          if (_orders.isEmpty) {
            Navigator.of(context).maybePop();
          }
        }
      }
    });
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.5, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    const Text(
                      'Active Orders',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8E6D4),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${_orders.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Order list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: _orders.isEmpty ? 1 : _orders.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (_orders.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(
                            'All orders completed.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.muted,
                            ),
                          ),
                        ),
                      );
                    }
                    return _OrderTrayRow(
                      order: _orders[index],
                      onView: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed(
                          AppRoutes.orderDetails,
                          arguments: OrderDetailsRouteArgs(
                            order: _orders[index],
                          ),
                        );
                      },
                      onCancel: _canCancel(_orders[index])
                          ? () => _cancelOrder(_orders[index])
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _canCancel(MarketOrder order) {
    if (order.status != OrderStatus.pending) {
      return false;
    }
    final cancelUntil = order.placedAt.add(FeeConfig.cancelWindow);
    return DateTime.now().isBefore(cancelUntil);
  }

  Future<void> _cancelOrder(MarketOrder order) async {
    try {
      await ref.read(orderServiceProvider.notifier).cancelOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order from ${order.vendorName} cancelled.',
            style: const TextStyle(),
          ),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } on OrderFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: const TextStyle()),
          backgroundColor: const Color(0xFFB3261E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

// ── Individual order row ──────────────────────────────────────────────────────

class _OrderTrayRow extends StatelessWidget {
  final MarketOrder order;
  final VoidCallback onView;
  final VoidCallback? onCancel;

  const _OrderTrayRow({
    required this.order,
    required this.onView,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Status dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.vendorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.items.length} item${order.items.length == 1 ? '' : 's'} · ${order.statusLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onCancel != null) ...[
                GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              GestureDetector(
                onTap: onView,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => const Color(0xFFF59E0B),
      OrderStatus.confirmed => const Color(0xFF3B82F6),
      OrderStatus.preparing => const Color(0xFF8B5CF6),
      OrderStatus.ready => const Color(0xFF059669),
      OrderStatus.outForDelivery => const Color(0xFF059669),
      OrderStatus.completed => AppTheme.textSecondary,
      OrderStatus.cancelled => const Color(0xFFEF4444),
      OrderStatus.rejected => const Color(0xFFEF4444),
    };
  }
}
