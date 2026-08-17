import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';

/// Unit-aware stock deduction.
///
/// Stock is stored in the product's own unit everywhere: kg products keep
/// fractional quantities (0.25kg stays 0.25kg) and pc products only allow
/// whole numbers. Returns the exact remaining stock and throws a typed
/// [OrderFailure] instead of silently accepting a partial/negative deduction.
/// Mirrors the trusted backend (`functions/src/orders.ts`).
double deductStock({
  required double stockQuantity,
  required double requestedQuantity,
  required String unit,
  String productName = 'Product',
}) {
  if (requestedQuantity <= 0) {
    throw const OrderFailure(
      OrderFailureType.invalidQuantity,
      message: 'Order quantity must be greater than zero.',
    );
  }
  if (unit == 'pc' && requestedQuantity != requestedQuantity.roundToDouble()) {
    throw OrderFailure(
      OrderFailureType.invalidQuantity,
      message:
          '$productName is sold per piece — fractional quantities are not allowed.',
    );
  }
  if (requestedQuantity > stockQuantity) {
    throw OrderFailure(
      OrderFailureType.outOfStock,
      message:
          'Insufficient stock: only $stockQuantity $unit of $productName available.',
    );
  }
  return stockQuantity - requestedQuantity;
}

/// Ordered status-transition graph, mirroring the trusted backend
/// (`functions/src/constants.ts`). Kept on the enum as an extension so the
/// generated enum file stays untouched.
extension OrderStatusPolicy on OrderStatus {
  bool get isTerminal => switch (this) {
    OrderStatus.completed ||
    OrderStatus.cancelled ||
    OrderStatus.rejected => true,
    _ => false,
  };

  bool canTransitionTo(OrderStatus next) => switch (this) {
    OrderStatus.pending => {
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.rejected,
      OrderStatus.cancelled,
    },
    OrderStatus.confirmed => {OrderStatus.preparing, OrderStatus.cancelled},
    OrderStatus.preparing => {OrderStatus.ready, OrderStatus.cancelled},
    OrderStatus.ready => {OrderStatus.outForDelivery, OrderStatus.completed},
    OrderStatus.outForDelivery => {OrderStatus.completed},
    OrderStatus.completed ||
    OrderStatus.cancelled ||
    OrderStatus.rejected => const <OrderStatus>{},
  }.contains(next);
}
