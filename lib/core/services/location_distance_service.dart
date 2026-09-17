import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:palengkego/core/config/fee_config.dart';

class PinnedAddress {
  final String addressText;
  final double latitude;
  final double longitude;

  const PinnedAddress({
    required this.addressText,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'addressText': addressText,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory PinnedAddress.fromJson(Map<String, dynamic> json) {
    return PinnedAddress(
      addressText: json['addressText'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 13.6218, // Default Naga City center
      longitude: (json['longitude'] as num?)?.toDouble() ?? 123.1948,
    );
  }
}

class LocationDistanceService {
  final http.Client _client;
  final String? _googleMapsApiKey;

  // Naga City People's Mall Default Coordinates
  static const double nagaPeoplesMallLat = 13.6218;
  static const double nagaPeoplesMallLng = 123.1948;

  LocationDistanceService({
    http.Client? client,
    String? googleMapsApiKey,
  })  : _client = client ?? http.Client(),
        _googleMapsApiKey = googleMapsApiKey ??
            const String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  /// Calculate delivery fee based on formula:
  /// Delivery Fee = Base Rate + (Rate per km * Distance in km)
  double calculateDeliveryFee({
    required double distanceKm,
    double baseRate = FeeConfig.deliveryBaseRate,
    double ratePerKm = FeeConfig.deliveryRatePerKm,
  }) {
    if (distanceKm <= 0) return baseRate;
    final fee = baseRate + (ratePerKm * distanceKm);
    return (fee * 100).roundToDouble() / 100.0;
  }

  /// Get driving road distance via Google Maps Distance Matrix API (with Haversine fallback)
  Future<double> getRoadDistanceKm({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    if (_googleMapsApiKey != null && _googleMapsApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/distancematrix/json'
          '?origins=$originLat,$originLng'
          '&destinations=$destLat,$destLng'
          '&key=$_googleMapsApiKey',
        );

        final response = await _client.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final rows = data['rows'] as List<dynamic>?;
          if (rows != null && rows.isNotEmpty) {
            final elements = rows[0]['elements'] as List<dynamic>?;
            if (elements != null && elements.isNotEmpty) {
              final distanceMeters =
                  elements[0]['distance']?['value'] as num?;
              if (distanceMeters != null) {
                return distanceMeters.toDouble() / 1000.0;
              }
            }
          }
        }
      } catch (_) {
        // Fallback to Haversine straight-line distance on API timeout or error
      }
    }

    return calculateHaversineDistanceKm(
      lat1: originLat,
      lon1: originLng,
      lat2: destLat,
      lon2: destLng,
    );
  }

  /// Haversine formula for distance calculation in kilometers. Static so mock
  /// offline pricing paths share the exact same math as the API-backed path.
  static double haversineKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const r = 6371.0; // Earth radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final dist = r * c;
    return (dist * 100).roundToDouble() / 100.0;
  }

  /// Haversine formula for distance calculation in kilometers
  double calculateHaversineDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) =>
      haversineKm(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2);

  static double _toRadians(double degree) => degree * (pi / 180.0);
}

/// The app-wide [LocationDistanceService]. Reads GOOGLE_MAPS_API_KEY from
/// `--dart-define`; without a key it falls back to straight-line (Haversine)
/// distance, which is what the mock backend and the edge functions compute.
final locationDistanceServiceProvider = Provider<LocationDistanceService>(
  (_) => LocationDistanceService(),
);
