/// Centralized fee and order configuration.
/// All order fee calculations and cancellation logic should reference these values.
abstract class FeeConfig {
  /// Flat delivery fee (₱) used as the fallback when the delivery address has
  /// no map pin. Pinned addresses are priced from distance instead.
  static const double deliveryFee = 49.0;
  static const double serviceFee = 15.0;
  static const double priorityFee = 29.0;

  /// Distance-based delivery pricing (formula in [LocationDistanceService]):
  /// `fee = deliveryBaseRate + (deliveryRatePerKm × distanceKm)` where
  /// distance is measured from Naga City People's Mall.
  static const double deliveryBaseRate = 30.0;
  static const double deliveryRatePerKm = 10.0;

  /// Maximum time after order placement during which cancellation is allowed.
  static const Duration cancelWindow = Duration(minutes: 5);
}
