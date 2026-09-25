import 'dart:math' as math;

/// Centralized fee and order configuration.
/// All order fee calculations and cancellation logic should reference these values.
abstract class FeeConfig {
  // Base + distance pricing mirrors supabase/functions/_shared/constants.ts
  static const double deliveryBaseCharge = 30.0;
  static const double deliveryPerKm = 10.0;
  static const double serviceFee = 0.0;
  static const double priorityFee = 29.0;

  /// Origin for distance calculation — Naga City People's Mall, Abella.
  static const double deliveryOriginLat = 13.6214;
  static const double deliveryOriginLng = 123.1838;

  /// Legacy flat fee (kept for fallback when no coordinates).
  static const double deliveryFee = deliveryBaseCharge;

  /// Maximum time after order placement during which cancellation is allowed.
  static const Duration cancelWindow = Duration(minutes: 5);

  /// Distance-based delivery fee: ₱30 base + ₱10/km from People's Mall.
  /// Priority adds ₱29 on top of the delivery fee.
  static double computeDeliveryFee({
    double? lat,
    double? lng,
    bool isPriority = false,
    bool isPickup = false,
  }) {
    if (isPickup) return 0;
    double fee = deliveryBaseCharge;
    if (lat != null && lng != null) {
      final km = _haversineKm(deliveryOriginLat, deliveryOriginLng, lat, lng);
      fee += km * deliveryPerKm;
    }
    if (isPriority) fee += priorityFee;
    return fee;
  }

  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}
