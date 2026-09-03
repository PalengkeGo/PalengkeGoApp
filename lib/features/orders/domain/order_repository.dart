import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/order_status_history.dart';

/// Contract for all order data operations.
abstract class OrderRepository {
  /// Place one or more orders from grouped line items.
  /// [groupedItems] maps vendor name -> (vendor image URL, line items).
  /// Returns the list of created orders.
  /// [paymentMethod] is one of 'cod' | 'cop' | 'gcash' | 'paymaya' | 'card'.
  /// Throws [OrderFailureType.outOfStock] / [OrderFailureType.invalidQuantity]
  /// when a line item cannot be fulfilled exactly from on-hand stock.
  Future<List<MarketOrder>> placeOrders({
    required Map<String, (String vendorImage, List<OrderLineItem> items)>
    groupedItems,
    required bool isPickup,
    String customerUid,
    String customerName,
    Map<String, String>? vendorNotes,
    String? deliveryAddress,
    bool isPriority = false,
    double priorityFee = 0.0,
    String paymentMethod = 'cod',
  });

  /// All orders placed by a specific customer.
  Future<List<MarketOrder>> getOrdersForCustomer(String customerUid);

  /// All orders received by a specific vendor stall.
  Future<List<MarketOrder>> getOrdersForVendor(String stallId);

  /// Update the status of a single order.
  /// [changedByUid] is the UID of whoever triggered the change.
  /// Throws [OrderFailureType.illegalStatusTransition] when [newStatus] is
  /// not reachable from the current status, and
  /// [OrderFailureType.alreadyTerminal] when the order is terminal.
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String? changedByUid,
    String? remarks,
    DateTime? estimatedReadyTime,
  });

  /// Cancel a pending order within the cancellation window.
  /// Completes successfully on cancellation, otherwise throws a typed
  /// [OrderFailure]: [OrderFailureType.cancelWindowExpired] when the window
  /// passed, [OrderFailureType.alreadyTerminal] when already cancelled or
  /// otherwise terminal, [OrderFailureType.illegalStatusTransition] when no
  /// longer pending, or [OrderFailureType.orderNotFound].
  Future<void> cancelOrder(String orderId, {String? reason, DateTime? now});

  /// Status change timeline for a specific order.
  Future<List<OrderStatusHistory>> getOrderHistory(String orderId);

  /// Customer-initiated refund request on a paid order. Flips the order to
  /// `refundRequested` and records [reason]; no money moves until a vendor
  /// or admin approves it. Throws [OrderFailure] if the order is not paid.
  Future<void> requestRefund(String orderId, {String? reason});

  /// Vendor/admin resolves a customer's refund request.
  /// [approve] runs the PayMongo refund money path; `false` declines and
  /// returns the order to `paid`. Throws [OrderFailure].
  Future<void> processRefundRequest(
    String orderId, {
    required bool approve,
    String? reason,
  });
}
