import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// OpenStreetMap background with interactive tile layer.
/// Centers on Naga City, Philippines by default (approximate).
/// Constrained to Naga City bounds to keep deliveries within the area.
class DeliveryAddressMapBackground extends StatelessWidget {
  final double width;
  final double height;
  final LatLng? initialCenter;
  final double initialZoom;
  final MapController? mapController;
  final Function(LatLng)? onMapReady;
  final Function(MapCamera, bool)? onPositionChanged;

  /// Approximate bounding box for Naga City, Camarines Sur.
  static final _nagaBounds = LatLngBounds(
    const LatLng(13.54, 123.13), // SW corner
    const LatLng(13.70, 123.27), // NE corner
  );

  const DeliveryAddressMapBackground({
    super.key,
    required this.width,
    required this.height,
    this.initialCenter,
    this.initialZoom = 16.0,
    this.mapController,
    this.onMapReady,
    this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final center = initialCenter ?? const LatLng(13.6220, 123.2137); // Naga City, Philippines

    return SizedBox(
      width: width,
      height: height,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: initialZoom,
          minZoom: 13,
          maxZoom: 19,
          // Keep the camera center inside Naga City so the user can't drag away.
          cameraConstraint: CameraConstraint.containCenter(bounds: _nagaBounds),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onMapReady: onMapReady != null ? () => onMapReady!(center) : null,
          onPositionChanged: onPositionChanged,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.palengkego.app',
            maxZoom: 19,
            subdomains: const ['a', 'b', 'c'],
            tileProvider: NetworkTileProvider(),
          ),
        ],
      ),
    );
  }
}
