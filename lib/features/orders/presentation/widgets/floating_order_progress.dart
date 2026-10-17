import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/navigation/app_routes.dart';

import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';

class FloatingOrderProgress extends ConsumerStatefulWidget {
  const FloatingOrderProgress({super.key});

  @override
  ConsumerState<FloatingOrderProgress> createState() =>
      _FloatingOrderProgressState();
}

class _FloatingOrderProgressState extends ConsumerState<FloatingOrderProgress> {
  static const double _headSize = 58;
  Offset? _position;
  bool _isDragging = false;

  Offset _clampPosition(Offset position, Size size, EdgeInsets padding) {
    const minLeft = 8.0;
    final minTop = padding.top + 8.0;
    final maxLeft = (size.width - _headSize - 8)
        .clamp(minLeft, double.infinity)
        .toDouble();
    final maxTop = (size.height - padding.bottom - _headSize - 8)
        .clamp(minTop, double.infinity)
        .toDouble();
    return Offset(
      position.dx.clamp(minLeft, maxLeft).toDouble(),
      position.dy.clamp(minTop, maxTop).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(orderServiceProvider);
    final media = MediaQuery.of(context);

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) => ordersAsync.when(
          data: (orders) {
            final activeOrders = orders
                .where(
                  (order) =>
                      order.status != OrderStatus.completed &&
                      order.status != OrderStatus.cancelled &&
                      order.status != OrderStatus.rejected,
                )
                .toList();
            if (activeOrders.isEmpty) return const SizedBox.shrink();

            final size = constraints.biggest;
            final fallback = Offset(
              size.width - _headSize - 12,
              size.height * 0.54,
            );
            final position = _clampPosition(
              _position ?? fallback,
              size,
              media.padding,
            );
            _position = position;

            return Stack(
              children: [
                AnimatedPositioned(
                  duration: _isDragging
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: position.dx,
                  top: position.dy,
                  child: GestureDetector(
                    key: const Key('active_orders_chat_head'),
                    onPanStart: (_) => setState(() => _isDragging = true),
                    onPanUpdate: (details) => setState(() {
                      _position = _clampPosition(
                        (_position ?? position) + details.delta,
                        size,
                        media.padding,
                      );
                    }),
                    onPanEnd: (_) => setState(() {
                      final current = _position ?? position;
                      final dockLeft =
                          current.dx + _headSize / 2 < size.width / 2;
                      _position = _clampPosition(
                        Offset(
                          dockLeft ? 8 : size.width - _headSize - 8,
                          current.dy,
                        ),
                        size,
                        media.padding,
                      );
                      _isDragging = false;
                    }),
                    onTap: () => showActiveOrdersTray(context, activeOrders),
                    child: Container(
                      width: _headSize,
                      height: _headSize,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Center(
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 20),
                              height: 20,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                activeOrders.length > 99
                                    ? '99+'
                                    : '${activeOrders.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ── Order tray bottom sheet ───────────────────────────────────────────────────

Future<void> showActiveOrdersTray(
  BuildContext context,
  List<MarketOrder> orders,
) async {
  if (orders.isEmpty || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OrderTraySheet(orders: orders),
  );
}

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
    ref.listenManual(orderServiceProvider, (previous, next) {
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
  }

  @override
  Widget build(BuildContext context) {
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
