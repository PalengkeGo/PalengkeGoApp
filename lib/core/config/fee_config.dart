/// Centralized fee and order configuration.
/// All order fee calculations and cancellation logic should reference these values.
abstract class FeeConfig {
  static const double deliveryFee = 49.0;
  static const double serviceFee = 15.0;
  static const double priorityFee = 29.0;

  /// Maximum time after order placement during which cancellation is allowed.
  static const Duration cancelWindow = Duration(minutes: 5);
}
