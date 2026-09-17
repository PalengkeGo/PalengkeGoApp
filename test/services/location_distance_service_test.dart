import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/services/location_distance_service.dart';

/// The one runnable check for the distance-based delivery pricing math:
/// both the Haversine formula and the base-rate fee fallback provably fail if
/// the formula in [LocationDistanceService] or [FeeConfig] is broken.
void main() {
  group('LocationDistanceService pricing math', () {
    // Constructed per-test: the service's default http.Client touches the
    // flutter_test mocked HttpOverrides, which only works inside a test zone.
    // No Google Maps API key is present in tests, so the client is never used.
    LocationDistanceService newService() => LocationDistanceService();

    test('haversine: 1° of latitude is ~111.19 km (6371 × π/180), rounded', () {
      final km = LocationDistanceService.haversineKm(
        lat1: 13.6218,
        lon1: 123.1948,
        lat2: 14.6218,
        lon2: 123.1948,
      );
      // The Dart haversine rounds to 2 decimals (the TS port does not).
      expect(km, closeTo(111.19, 0.001));
      expect(km, closeTo(6371.0 * 3.141592653589793 / 180, 0.01));
    });

    test('fee formula: base + (rate per km × distance), rounded to centavos', () {
      final service = newService();
      expect(
        service.calculateDeliveryFee(distanceKm: 0),
        FeeConfig.deliveryBaseRate,
      );
      const km = 2.5;
      expect(
        service.calculateDeliveryFee(distanceKm: km),
        closeTo(
          FeeConfig.deliveryBaseRate +
              FeeConfig.deliveryRatePerKm * km,
          0.01,
        ),
      );
    });

    test('same vector as the trusted backend (People\'s Mall → 1° north)', () {
      final service = newService();
      final km = LocationDistanceService.haversineKm(
        lat1: LocationDistanceService.nagaPeoplesMallLat,
        lon1: LocationDistanceService.nagaPeoplesMallLng,
        lat2: 14.6218,
        lon2: 123.1948,
      );
      final fee = service.calculateDeliveryFee(distanceKm: km);
      expect(
        fee,
        closeTo(
          FeeConfig.deliveryBaseRate +
              FeeConfig.deliveryRatePerKm * km,
          0.01,
        ),
      );
      // A pinned address ~111 km away must cost more than the flat ₱49.
      expect(fee, greaterThan(FeeConfig.deliveryFee));
    });
  });
}