import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';

class VendorOrdersNotifier extends AsyncNotifier<List<MarketOrder>> {
  @override
  Future<List<MarketOrder>> build() async {
    final repo = ref.watch(orderRepositoryProvider);
    final vendorId = ref.watch(currentVendorIdProvider);
    // Watch orderServiceProvider to automatically refresh vendor orders when a new order is placed or modified
    ref.watch(orderServiceProvider);
    if (vendorId == null) return const [];
    final orders = await repo.getOrdersForVendor(vendorId);
    return orders;
  }

  Future<void> _updateStatus(String orderId, OrderStatus newStatus) async {
    final repo = ref.read(orderRepositoryProvider);
    final uid = ref.read(authProvider)?.uid;
    final vendorId = ref.read(currentVendorIdProvider);
    if (vendorId == null) {
      throw StateError('Vendor session required to update orders');
    }

    // Get order before update to get details (e.g. vendor name, estimated time)
    final ordersBefore = await repo.getOrdersForVendor(vendorId);
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
      ref.invalidate(vendorProductsProvider(vendorId));
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
  Future<void> completeOrder(String orderId) =>
      _updateStatus(orderId, OrderStatus.completed);

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    final repo = ref.read(orderRepositoryProvider);
    final uid = ref.read(authProvider)?.uid;
    final vendorId = ref.read(currentVendorIdProvider);
    if (vendorId == null) {
      throw StateError('Vendor session required to cancel orders');
    }

    final ordersBefore = await repo.getOrdersForVendor(vendorId);
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
    if (vendorId == null) {
      throw StateError('Vendor session required to update orders');
    }

    await repo.updateOrderStatus(
      orderId,
      currentStatus,
      changedByUid: uid,
      estimatedReadyTime: time,
    );

    final ordersAfter = await repo.getOrdersForVendor(vendorId);
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
