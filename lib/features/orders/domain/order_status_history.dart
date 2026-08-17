import 'package:palengkego/features/orders/domain/order_status.dart';

/// A single step in an order's lifecycle.
///
/// Matches the ORDER_STATUS_HISTORY ERD entity.
/// Stored as a subcollection: `orders/{orderId}/statusHistory/{historyId}`
class OrderStatusHistory {
  const OrderStatusHistory({
    required this.historyId,
    required this.orderId,
    this.previousStatus,
    required this.newStatus,
    required this.changedBy,
    required this.changedAt,
    this.remarks,
  });

  /// Firestore document ID.
  final String historyId;

  /// Parent order ID.
  final String orderId;

  /// The status before this change. Null for the initial `pending` entry.
  final OrderStatus? previousStatus;

  /// The status after this change.
  final OrderStatus newStatus;

  /// UID of the user who triggered the change (customer, vendor, or system).
  final String changedBy;

  final DateTime changedAt;

  /// Optional note from the vendor or system (e.g. "Customer was unreachable").
  final String? remarks;

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'previousStatus': previousStatus?.name,
      'newStatus': newStatus.name,
      'changedBy': changedBy,
      'changedAt': changedAt.toIso8601String(),
      'remarks': remarks,
    };
  }

  factory OrderStatusHistory.fromFirestore(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return OrderStatusHistory(
      historyId: id,
      orderId: data['orderId'] as String? ?? '',
      previousStatus: data['previousStatus'] != null
          ? OrderStatus.values.firstWhere(
              (s) => s.name == data['previousStatus'],
              orElse: () => OrderStatus.pending,
            )
          : null,
      newStatus: OrderStatus.values.firstWhere(
        (s) => s.name == (data['newStatus'] as String? ?? 'pending'),
        orElse: () => OrderStatus.pending,
      ),
      changedBy: data['changedBy'] as String? ?? '',
      changedAt: data['changedAt'] != null
          ? DateTime.parse(data['changedAt'] as String)
          : DateTime.now(),
      remarks: data['remarks'] as String?,
    );
  }
}
