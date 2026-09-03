import 'dart:async';

import 'package:flutter/material.dart';
import 'package:palengkego/core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Google Maps integration scaffold — PalengkeGo delivery tracker
// ---------------------------------------------------------------------------
//
// This file is intentionally dependency-light: it compiles with only the
// packages already in pubspec.yaml. `google_maps_flutter` is NOT in pubspec
// yet, so the real map surface is a placeholder Container and the exact
// wiring points are marked with TODO(map) comments.
//
// To activate real maps:
//   1. pubspec.yaml — add the map plugin (TODO: add, then `flutter pub get`):
//        dependencies:
//          google_maps_flutter: ^2.16.0
//      Note: `geolocator` (^13.0.2) is ALREADY in pubspec.yaml, so the
//      permission + live-location plumbing in [TrackingLocationService]
//      needs no new dependency for location — only the map plugin.
//   2. Android — add the Maps API key to
//      android/app/src/main/AndroidManifest.xml:
//        <meta-data android:name="com.google.android.geo.API_KEY"
//                   android:value="YOUR_KEY" />
//   3. iOS — add the Maps API key to Info.plist (com.google.MGLMapsApiKey).
//   4. Replace the placeholder in [_GoogleMapsScaffoldState._buildRealMap]
//      with the commented-out `GoogleMap(...)` block.
//
// Suggested entry point (additive — no router changes required today):
//   - Track Order screen (AppRoutes.trackOrder): swap `TrackingMapPreview`
//     for `GoogleMapsScaffold(orderId: order.id,
//     initialCameraTarget: (stallLat, stallLng))` once the key is live.
//   - Vendor order details screen: same replacement.
//   - Optionally expose a "Live map" settings toggle later; the scaffold
//     degrades to the placeholder state automatically when unconfigured.
// ---------------------------------------------------------------------------

/// One location fix emitted by [TrackingLocationService.positions].
class TrackingPosition {
  const TrackingPosition({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;

  /// Horizontal accuracy of the fix in meters (null when unknown).
  final double? accuracyMeters;

  final DateTime timestamp;
}

/// Runtime location permission result.
enum LocationPermissionState { unknown, granted, denied, permanentlyDenied }

/// Abstraction over "request location permission + stream live fixes".
///
/// The delivery tracker depends on this interface (never on a concrete
/// plugin) so the mock and the real geolocator-backed implementation are
/// interchangeable.
abstract class TrackingLocationService {
  /// Requests the runtime location permission and returns its state.
  Future<LocationPermissionState> requestLocationPermission();

  /// Stream of live position fixes (emits while tracking is active).
  Stream<TrackingPosition> get positions;

  /// Starts emitting location fixes. No-op if already tracking.
  Future<void> startTracking();

  /// Stops emitting fixes and releases the native watcher.
  Future<void> stopTracking();

  /// Releases plugin resources. Call when the owning screen is disposed.
  Future<void> dispose();
}

/// Factory for the tracker's location service.
///
/// TODO(map): return the real geolocator-based implementation (sketch in
/// [MockTrackingLocationService]'s doc comment) instead of the mock.
TrackingLocationService createTrackingLocationService() =>
    MockTrackingLocationService();

/// Mock implementation for development — emits a slow drift toward the
/// demo stall so the tracker UI has live data without permissions.
///
/// TODO(map): replace with the real implementation. Sketch (geolocator is
/// already a project dependency):
/// ```dart
/// import 'package:geolocator/geolocator.dart';
///
/// class GeolocatorTrackingLocationService extends TrackingLocationService {
///   StreamSubscription<Position>? _sub;
///   final StreamController<TrackingPosition> _controller =
///       StreamController<TrackingPosition>.broadcast();
///
///   @override
///   Future<LocationPermissionState> requestLocationPermission() async {
///     if (!await Geolocator.isLocationServiceEnabled()) {
///       return LocationPermissionState.denied; // services off
///     }
///     var permission = await Geolocator.checkPermission();
///     if (permission == LocationPermission.denied) {
///       permission = await Geolocator.requestPermission();
///     }
///     return switch (permission) {
///       LocationPermission.always ||
///       LocationPermission.whileInUse => LocationPermissionState.granted,
///       LocationPermission.denied => LocationPermissionState.denied,
///       _ => LocationPermissionState.permanentlyDenied,
///     };
///   }
///
///   @override
///   Stream<TrackingPosition> get positions => _controller.stream;
///
///   @override
///   Future<void> startTracking() async {
///     if (_sub != null) return;
///     _sub = Geolocator.getPositionStream(
///       locationSettings: const LocationSettings(
///         accuracy: LocationAccuracy.high,
///         distanceFilter: 5,
///       ),
///     ).listen((p) => _controller.add(TrackingPosition(
///           latitude: p.latitude,
///           longitude: p.longitude,
///           accuracyMeters: p.accuracy,
///           timestamp: DateTime.now(),
///         )));
///   }
///
///   @override
///   Future<void> stopTracking() async {
///     await _sub?.cancel();
///     _sub = null;
///   }
///
///   @override
///   Future<void> dispose() async {
///     await stopTracking();
///     await _controller.close();
///   }
/// }
/// ```
class MockTrackingLocationService extends TrackingLocationService {
  // Demo stall location (Quezon City).
  static const double _stallLat = 14.5995;
  static const double _stallLng = 120.9842;

  final StreamController<TrackingPosition> _controller =
      StreamController<TrackingPosition>.broadcast();
  StreamSubscription<void>? _ticker;
  int _tick = 0;
  bool _disposed = false;

  @override
  Future<LocationPermissionState> requestLocationPermission() async {
    // TODO(map): real permission flow lives in the geolocator implementation.
    return LocationPermissionState.granted;
  }

  @override
  Stream<TrackingPosition> get positions => _controller.stream;

  @override
  Future<void> startTracking() async {
    if (_ticker != null || _disposed) return;
    // Emit a slow approach toward the stall (converges after ~10 ticks).
    _ticker = Stream.periodic(const Duration(seconds: 3)).listen((_) {
      _tick += 1;
      const drift = 0.0015;
      final fade = (10 - _tick).clamp(0, 10) / 10;
      if (!(_controller.isClosed)) {
        _controller.add(
          TrackingPosition(
            latitude: _stallLat + drift * fade,
            longitude: _stallLng - drift * fade,
            accuracyMeters: 12,
            timestamp: DateTime.now(),
          ),
        );
      }
    });
  }

  @override
  Future<void> stopTracking() async {
    await _ticker?.cancel();
    _ticker = null;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stopTracking();
    await _controller.close();
  }
}

/// Whether Google Maps credentials are available for this build.
class GoogleMapsConfig {
  const GoogleMapsConfig({this.isConfigured = false});

  /// TODO(map): derive from real configuration (e.g. a flag in
  /// core/config or a stored API key). Until then the scaffold renders the
  /// "map coming soon / not configured" placeholder state.
  final bool isConfigured;
}

/// Drop-in map surface for the delivery tracker.
///
/// Renders the live location stream and — once Google Maps is configured —
/// the real map. Today it shows the placeholder state; the TODO(map) block
/// in [_GoogleMapsScaffoldState._buildRealMap] marks where `GoogleMap` goes.
class GoogleMapsScaffold extends StatefulWidget {
  const GoogleMapsScaffold({
    super.key,
    this.height = 280,
    this.config = const GoogleMapsConfig(),
    this.locationService,
    this.orderId,
    this.initialCameraTarget,
  });

  /// Rendered height (the Track Order screen uses 280).
  final double height;

  final GoogleMapsConfig config;

  /// Location service to track with. When null the widget creates (and owns,
  /// disposing in `dispose`) an instance from [createTrackingLocationService].
  /// Keep the instance stable across frames; it is not swapped at runtime.
  final TrackingLocationService? locationService;

  /// Order this map is tracking (overlay label only; optional).
  final String? orderId;

  /// (latitude, longitude) the camera should center on once the map is live.
  final (double, double)? initialCameraTarget;

  @override
  State<GoogleMapsScaffold> createState() => _GoogleMapsScaffoldState();
}

class _GoogleMapsScaffoldState extends State<GoogleMapsScaffold> {
  late final TrackingLocationService _service =
      widget.locationService ?? createTrackingLocationService();
  late final bool _ownsService = widget.locationService == null;

  StreamSubscription<TrackingPosition>? _positionSub;
  TrackingPosition? _lastPosition;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    final permission = await _service.requestLocationPermission();
    if (permission == LocationPermissionState.denied ||
        permission == LocationPermissionState.permanentlyDenied) {
      // TODO(map): surface a "Location permission needed" state in the
      // placeholder (snack/dialog + re-prompt) instead of returning quietly.
      return;
    }
    if (!mounted) return;
    _positionSub = _service.positions.listen((position) {
      if (mounted) setState(() => _lastPosition = position);
    });
    await _service.startTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    if (_ownsService) {
      unawaited(_service.dispose());
    } else {
      unawaited(_service.stopTracking());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: widget.config.isConfigured
            ? _buildRealMap()
            : _buildPlaceholder(
                message: 'Map coming soon — Google Maps not configured',
              ),
      ),
    );
  }

  Widget _buildRealMap() {
    // TODO(map): once `google_maps_flutter` is in pubspec.yaml, replace this
    // body with the real map. Wiring sketch:
    //
    // ```dart
    // import 'package:google_maps_flutter/google_maps_flutter.dart';
    //
    // // Field in _GoogleMapsScaffoldState:
    // // final Completer<GoogleMapController> _mapController = Completer();
    //
    // StreamBuilder<TrackingPosition>(
    //   stream: _service.positions,
    //   builder: (context, snapshot) {
    //     final position = snapshot.data;
    //     final target = widget.initialCameraTarget;
    //     return GoogleMap(
    //       onMapCreated: (controller) => _mapController.complete(controller),
    //       initialCameraPosition: CameraPosition(
    //         target: LatLng(
    //           target?.$1 ?? position?.latitude ?? _fallbackLat,
    //           target?.$2 ?? position?.longitude ?? _fallbackLng,
    //         ),
    //         zoom: 15,
    //       ),
    //       myLocationEnabled: true,
    //       myLocationButtonEnabled: true,
    //       markers: {
    //         if (position != null)
    //           Marker(
    //             markerId: const MarkerId('delivery-tracker'),
    //             position: LatLng(position.latitude, position.longitude),
    //           ),
    //       },
    //       // Polyline: accumulate `positions` fixes into a LatLngList and
    //       // render the rider's path with `polyline: Polyline(...)`.
    //     );
    //   },
    // );
    // ```
    return _buildPlaceholder(message: 'Map coming soon — Google Maps not configured');
  }

  /// Quiet map-placeholder surface: soft green gradient + grid, the status
  /// message pinned at the bottom, and a live-fix chip once tracking emits.
  Widget _buildPlaceholder({required String message}) {
    final last = _lastPosition;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD9FBE6), Color(0xFFE9F7EF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: _MapGridPainter(),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.map_outlined,
                size: 44,
                color: AppTheme.primaryGreen,
              ),
            ),
            if (last != null)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${last.latitude.toStringAsFixed(5)}, '
                    '${last.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            if (widget.orderId != null)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Order ${widget.orderId}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faint street-grid painter for the placeholder map surface (mirrors the
/// look of `TrackingMapPreview`).
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBBF7D0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
