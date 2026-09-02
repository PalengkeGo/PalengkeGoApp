import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/mock/mock_data.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_policy.dart';
import 'package:palengkego/features/orders/domain/order_repository.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/order_status_history.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';

import 'package:palengkego/features/orders/data/shared_order_store.dart';

class MockOrderRepository implements OrderRepository {
  MockOrderRepository({SharedOrderStore? store}) : _store = store ?? SharedOrderStore();

  static const _cancelWindow = FeeConfig.cancelWindow;

  final SharedOrderStore _store;

  // ── Seeded mock orders ────────────────────────────────────────────────────
  List<MarketOrder> get _orders => _store.orders;

  // Status history per orderId.
  Map<String, List<OrderStatusHistory>> get _history => _store.history;

  int _seq = 1;

  @override
  Future<List<MarketOrder>> placeOrders({
    required Map<String, (String vendorImage, List<OrderLineItem> items)>
    groupedItems,
    required bool isPickup,
    String customerUid = '',
    String customerName = 'Customer',
    Map<String, String>? vendorNotes,
    String? deliveryAddress,
    bool isPriority = false,
    double priorityFee = 0.0,
    String paymentMethod = 'cod',
  }) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final todayPrefix = '#$dateStr';
    final maxSeq = _store.orders
        .where((o) => o.id.startsWith(todayPrefix))
        .map((o) => int.tryParse(o.id.replaceFirst(todayPrefix, '')) ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    _seq = maxSeq + 1;

    final created = <MarketOrder>[];

    // Validate against on-hand stock before creating anything, so a failing
    // order leaves no partial orders behind (same contract as Firestore).
    for (final entry in groupedItems.entries) {
      final vendor = MockDataService.featuredVendors.firstWhere(
        (v) => v['name'] == entry.key,
        orElse: () => const {'id': ''},
      );
      final vendorId = vendor['id'] as String;
      if (vendorId.isEmpty) continue;

      for (final item in entry.value.$2) {
        if (item.productId.startsWith('dummy') ||
            item.productId.startsWith('recipe_')) {
          continue;
        }
        final productIndex = MockDataService.products.indexWhere(
          (p) => p['name'] == item.productName && p['vendorId'] == vendorId,
        );
        if (productIndex == -1) continue;
        deductStock(
          // Seed products carry no stockQuantity; the mock treats an absent
          // value as 15.0 (same default as MockDataService stock helpers).
          stockQuantity:
              (MockDataService.products[productIndex]['stockQuantity'] as num?)
                  ?.toDouble() ??
              15.0,
          requestedQuantity: item.quantity,
          unit: MockDataService.products[productIndex]['unit'] as String? ?? '',
          productName: item.productName,
        );
      }
    }

    for (final entry in groupedItems.entries) {
      final orderId = '#$dateStr${_seq++}';
      final vendorName = entry.key;
      final vendorImage = entry.value.$1;
      final lineItems = entry.value.$2;

      final vendor = MockDataService.featuredVendors.firstWhere(
        (v) => v['name'] == vendorName,
        orElse: () => {'id': 'stall holder-001'},
      );
      final stallId = vendor['id'] as String;

      final order = MarketOrder(
        id: orderId,
        customerUid: customerUid.isEmpty ? 'customer-001' : customerUid,
        stallId: stallId,
        vendorName: vendorName,
        vendorImage: vendorImage,
        customerName: customerName,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
        paymentMethod: paymentMethod,
        fulfillmentMethod: isPickup
            ? FulfillmentMethod.pickup
            : FulfillmentMethod.delivery,
        deliveryAddress: isPickup
            ? null
            : (deliveryAddress ?? '123 Default Address'),
        deliveryFee: isPickup ? 0.0 : FeeConfig.deliveryFee,
        serviceFee: FeeConfig.serviceFee,
        isPriority: isPickup ? false : isPriority,
        priorityFee: isPickup ? 0.0 : priorityFee,
        placedAt: now,
        notes: vendorNotes?[entry.key],
        items: lineItems,
      );
      _orders.add(order);
      _history[orderId] = [
        OrderStatusHistory(
          historyId: 'h-$orderId-1',
          orderId: orderId,
          newStatus: OrderStatus.pending,
          changedBy: customerUid.isEmpty ? 'customer' : customerUid,
          changedAt: now,
        ),
      ];

      created.add(order);
    }
    await _store.save();
    return created;
  }

  @override
  Future<List<MarketOrder>> getOrdersForCustomer(String customerUid) async {
    // In mock mode all orders belong to the same customer.
    final sorted = List<MarketOrder>.from(_orders)
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    return List.unmodifiable(sorted);
  }

  @override
  Future<List<MarketOrder>> getOrdersForVendor(String stallId) async {
    // Resolve vendor name from ID
    final vendor = MockDataService.featuredVendors.firstWhere(
      (v) => v['id'] == stallId,
      orElse: () => {'name': stallId},
    );
    final vendorName = vendor['name'] as String;
    final filtered = _orders.where((o) => o.vendorName == vendorName).toList();
    final sorted = List<MarketOrder>.from(filtered)
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    return List.unmodifiable(sorted);
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String? changedByUid,
    String? remarks,
    DateTime? estimatedReadyTime,
  }) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;

    final previous = _orders[idx].status;
    if (previous.isTerminal) {
      throw OrderFailure(
        OrderFailureType.alreadyTerminal,
        message:
            'Order #$orderId is already ${previous.label} and can no longer be changed.',
      );
    }
    // Same-status re-record (e.g. a new estimated ready time) is not a
    // transition, so it bypasses the graph but still persists the fields.
    if (previous != newStatus && !previous.canTransitionTo(newStatus)) {
      throw OrderFailure(
        OrderFailureType.illegalStatusTransition,
        message:
            'Cannot change order #$orderId from ${previous.label} to ${newStatus.label}.',
      );
    }

    _orders[idx] = _orders[idx].copyWith(
      status: newStatus,
      // Only cash orders (COD / cash on pickup) are marked paid at completion;
      // online payments flip to paid via the verified webhook (mirrors the
      // trusted backend).
      paymentStatus: (newStatus == OrderStatus.completed &&
              (_orders[idx].paymentMethod == 'cod' ||
                  _orders[idx].paymentMethod == 'cop'))
          ? PaymentStatus.paid
          : _orders[idx].paymentStatus,
      estimatedReadyTime: estimatedReadyTime ?? _orders[idx].estimatedReadyTime,
      cancellationReason:
          (newStatus == OrderStatus.cancelled ||
              newStatus == OrderStatus.rejected)
          ? (remarks ?? _orders[idx].cancellationReason)
          : _orders[idx].cancellationReason,
    );

    if (newStatus == OrderStatus.completed &&
        previous != OrderStatus.completed) {
      for (final item in _orders[idx].items) {
        MockDataService.decreaseProductStockByName(
          item.productName,
          _orders[idx].vendorName,
          item.quantity,
        );
      }
    }

    _history.putIfAbsent(orderId, () => []);
    _history[orderId]!.add(
      OrderStatusHistory(
        historyId: 'h-$orderId-${_history[orderId]!.length + 1}',
        orderId: orderId,
        previousStatus: previous,
        newStatus: newStatus,
        changedBy: changedByUid ?? 'system',
        changedAt: DateTime.now(),
        remarks: remarks,
      ),
    );
    await _store.save();
  }

  @override
  Future<void> cancelOrder(
    String orderId, {
    String? reason,
    DateTime? now,
  }) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) {
      throw const OrderFailure(
        OrderFailureType.orderNotFound,
        message: 'Order not found.',
      );
    }

    final order = _orders[idx];
    if (order.status != OrderStatus.pending) {
      throw OrderFailure(
        order.status.isTerminal
            ? OrderFailureType.alreadyTerminal
            : OrderFailureType.illegalStatusTransition,
        message:
            'Order #$orderId can only be cancelled while pending (current: ${order.status.label}).',
      );
    }

    final cancelUntil = order.placedAt.add(_cancelWindow);
    if ((now ?? DateTime.now()).isAfter(cancelUntil)) {
      throw OrderFailure(
        OrderFailureType.cancelWindowExpired,
        message: 'The cancellation window for order #$orderId has expired.',
      );
    }

    await updateOrderStatus(
      orderId,
      OrderStatus.cancelled,
      changedByUid: 'customer',
      remarks: reason,
    );
  }

  @override
  Future<List<OrderStatusHistory>> getOrderHistory(String orderId) async {
    return List.unmodifiable(_history[orderId] ?? []);
  }

  @override
  Future<void> requestRefund(String orderId, {String? reason}) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) {
      throw const OrderFailure(
        OrderFailureType.orderNotFound,
        message: 'Order not found.',
      );
    }
    final order = _orders[idx];
    if (order.paymentStatus != PaymentStatus.paid) {
      throw OrderFailure(
        OrderFailureType.illegalStatusTransition,
        message:
            'Order #$orderId can only be refunded once paid (current: ${order.paymentStatus.label}).',
      );
    }
    _orders[idx] = order.copyWith(
      paymentStatus: PaymentStatus.refundRequested,
      refundRequestReason: reason,
      refundRequestedAt: DateTime.now(),
    );
    _history.putIfAbsent(orderId, () => []);
    _history[orderId]!.add(
      OrderStatusHistory(
        historyId: 'h-$orderId-${_history[orderId]!.length + 1}',
        orderId: orderId,
        previousStatus: order.status,
        newStatus: order.status,
        changedBy: 'customer',
        changedAt: DateTime.now(),
        remarks: 'Refund requested by customer',
      ),
    );
    await _store.save();
  }

  @override
  Future<void> processRefundRequest(
    String orderId, {
    required bool approve,
    String? reason,
  }) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) {
      throw const OrderFailure(
        OrderFailureType.orderNotFound,
        message: 'Order not found.',
      );
    }
    final order = _orders[idx];
    if (order.paymentStatus != PaymentStatus.refundRequested) {
      throw OrderFailure(
        order.status.isTerminal
            ? OrderFailureType.alreadyTerminal
            : OrderFailureType.illegalStatusTransition,
        message:
            'Order #$orderId has no pending refund request (current: ${order.paymentStatus.label}).',
      );
    }
    _orders[idx] = approve
        ? order.copyWith(
            paymentStatus: PaymentStatus.refunded,
            refundId: 'ref_mock_$orderId',
            refundedAmount: order.total,
            refundRequestReason: null,
            refundRequestedAt: null,
          )
        : order.copyWith(
            paymentStatus: PaymentStatus.paid,
            refundRequestReason: null,
            refundRequestedAt: null,
          );
    _history.putIfAbsent(orderId, () => []);
    _history[orderId]!.add(
      OrderStatusHistory(
        historyId: 'h-$orderId-${_history[orderId]!.length + 1}',
        orderId: orderId,
        previousStatus: order.status,
        newStatus: order.status,
        changedBy: 'vendor',
        changedAt: DateTime.now(),
        remarks: approve ? 'Refund approved' : 'Refund request declined',
      ),
    );
    await _store.save();
  }
}
