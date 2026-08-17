/// Kind of failure that can prevent an order action from succeeding.
///
/// Every thrown [OrderFailure] carries a machine-readable [type] plus a
/// human-readable [message] so the UI can surface a specific reason instead
/// of a generic "something went wrong".
enum OrderFailureType {
  /// Not enough stock on hand for the requested quantity.
  outOfStock,

  /// Quantity is invalid for the product's unit (e.g. 1.5 pieces).
  invalidQuantity,

  /// The provider was not signed in.
  unauthenticated,

  /// The order no longer exists.
  orderNotFound,

  /// The cancellation window has already passed.
  cancelWindowExpired,

  /// The order is in a terminal state and can no longer change.
  alreadyTerminal,

  /// The requested status change is not allowed by the state machine.
  illegalStatusTransition,

  /// The trusted backend throttled the request (per-user rate limit).
  rateLimited,
}

/// Typed, user-facing failure for order operations.
class OrderFailure implements Exception {
  const OrderFailure(this.type, {required this.message});

  final OrderFailureType type;
  final String message;

  @override
  String toString() => 'OrderFailure($type): $message';
}
