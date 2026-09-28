import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';

class VendorOrdersNotifier extends AsyncNotifier<List<MarketOrder>> {
  final Set<String> _notifiedOrderIds = {};
  Timer? _pollingTimer;

  @override
  Future<List<MarketOrder>> build() async {
    ref.watch(dataRefreshSignal);
    ref.watch(orderServiceProvider);
    final repo = ref.watch(orderRepositoryProvider);
    final vendorId = ref.watch(currentVendorIdProvider);
    final myStall = ref.watch(vendorStallProvider);

    _pollingTimer?.cancel();
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (ref.mounted) {
          ref.invalidateSelf();
        }
      });
    }
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });

    if (vendorId == null && myStall.stallId.isEmpty) return const [];
    final effectiveId = vendorId ?? myStall.stallId;
    final orders = await repo.getOrdersForVendor(
      effectiveId,
      vendorName: myStall.name,
    );
    final notifService = ref.read(notificationServiceProvider);
    for (final order in orders) {
      if (order.status == OrderStatus.pending &&
          !_notifiedOrderIds.contains(order.id)) {
        _notifiedOrderIds.add(order.id);
        await notifService.onNewOrderArrived(
          order.id,
          order.customerName,
          order.total,
        );
      }
    }
    return orders;
  }

  Future<void> _updateStatus(String orderId, OrderStatus newStatus) async {
    final repo = ref.read(orderRepositoryProvider);
    final uid = ref.read(authProvider)?.uid;
    final vendorId = ref.read(currentVendorIdProvider);
    final myStall = ref.read(vendorStallProvider);
    final effectiveId = vendorId ?? myStall.stallId;
    if (effectiveId.isEmpty) {
      throw StateError('Vendor session required to update orders');
    }

    // Get order before update to get details (e.g. vendor name, estimated time)
    final ordersBefore = await repo.getOrdersForVendor(
      effectiveId,
      vendorName: myStall.name,
    );
    final prevOrder = ordersBefore.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw Exception('Order not found'),
    );

    await repo.updateOrderStatus(orderId, newStatus, changedByUid: uid);

    // Trigger notification
    ref
        .read(notificationServiceProvider)
        .onOrderStatusChanged(
          orderId,
          prevOrder.vendorName,
          newStatus,
          estimatedReadyTime: prevOrder.estimatedReadyTime,
        );

    // If order is completed, notify data refresh signal so UI reloads
    if (newStatus == OrderStatus.completed) {
      ref.invalidate(vendorProductsProvider(effectiveId));
      ref.read(dataRefreshSignal.notifier).notify();
    }

    ref.read(orderServiceProvider.notifier).refresh();
    ref.invalidateSelf(); // Refresh the list
  }

  Future<void> acceptOrder(String orderId) =>
      _updateStatus(orderId, OrderStatus.preparing);
  Future<void> rejectOrder(String orderId) =>
      _updateStatus(orderId, OrderStatus.cancelled);
  Future<void> markOrderReady(String orderId) =>
      _updateStatus(orderId, OrderStatus.ready);
  Future<void> markOrderOutForDelivery(String orderId) =>
      _updateStatus(orderId, OrderStatus.outForDelivery);
  Future<void> completeOrder(String orderId) =>
      _updateStatus(orderId, OrderStatus.completed);

  /// Resolves a customer's refund request as the vendor. Approve runs the
  /// money path; decline returns the order to paid.
  Future<void> processRefundRequest(
    String orderId, {
    required bool approve,
  }) async {
    final repo = ref.read(orderRepositoryProvider);
    await repo.processRefundRequest(orderId, approve: approve);
    ref.read(orderServiceProvider.notifier).refresh();
    ref.invalidateSelf();
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    final repo = ref.read(orderRepositoryProvider);
    final uid = ref.read(authProvider)?.uid;
    final vendorId = ref.read(currentVendorIdProvider);
    final myStall = ref.read(vendorStallProvider);
    final effectiveId = vendorId ?? myStall.stallId;
    if (effectiveId.isEmpty) {
      throw StateError('Vendor session required to cancel orders');
    }

    final ordersBefore = await repo.getOrdersForVendor(
      effectiveId,
      vendorName: myStall.name,
    );
    final prevOrder = ordersBefore.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw Exception('Order not found'),
    );

    await repo.updateOrderStatus(
      orderId,
      OrderStatus.cancelled,
      changedByUid: uid,
      remarks: reason,
    );

    ref
        .read(notificationServiceProvider)
        .onOrderStatusChanged(
          orderId,
          prevOrder.vendorName,
          OrderStatus.cancelled,
          estimatedReadyTime: prevOrder.estimatedReadyTime,
        );

    ref.read(orderServiceProvider.notifier).refresh();
    ref.invalidateSelf();
  }

  Future<void> updateEstimatedReadyTime(
    String orderId,
    DateTime time,
    OrderStatus currentStatus,
  ) async {
    final repo = ref.read(orderRepositoryProvider);
    final uid = ref.read(authProvider)?.uid;
    final vendorId = ref.read(currentVendorIdProvider);
    final myStall = ref.read(vendorStallProvider);
    final effectiveId = vendorId ?? myStall.stallId;
    if (effectiveId.isEmpty) {
      throw StateError('Vendor session required to update orders');
    }

    await repo.updateOrderStatus(
      orderId,
      currentStatus,
      changedByUid: uid,
      estimatedReadyTime: time,
    );

    final ordersAfter = await repo.getOrdersForVendor(
      effectiveId,
      vendorName: myStall.name,
    );
    final order = ordersAfter.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw Exception('Order not found'),
    );

    // Trigger notification with updated ready time
    ref
        .read(notificationServiceProvider)
        .onOrderStatusChanged(
          orderId,
          order.vendorName,
          currentStatus,
          estimatedReadyTime: time,
        );

    ref.read(orderServiceProvider.notifier).refresh();
    ref.invalidateSelf();
  }
}

final vendorOrdersProvider =
    AsyncNotifierProvider<VendorOrdersNotifier, List<MarketOrder>>(
      VendorOrdersNotifier.new,
    );

class VendorDashboardTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void select(int index) => state = index;
}

final vendorDashboardTabIndexProvider =
    NotifierProvider<VendorDashboardTabNotifier, int>(
      VendorDashboardTabNotifier.new,
    );

class VendorOrdersTabNotifier extends Notifier<int> {
  @override
  int build() => 0; // 0 = Pending, 1 = Completed
  void select(int index) => state = index;
}

final vendorOrdersTabIndexProvider =
    NotifierProvider<VendorOrdersTabNotifier, int>(
      VendorOrdersTabNotifier.new,
    );
