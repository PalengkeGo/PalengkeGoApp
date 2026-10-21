import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';

class TrackingMapPreview extends StatelessWidget {
  const TrackingMapPreview({super.key, required this.order});

  final MarketOrder order;

  @override
  Widget build(BuildContext context) {
    final isPickup = order.isPickup;
    final deliveryLat = order.deliveryLatitude;
    final deliveryLng = order.deliveryLongitude;
    final hasDeliveryCoords =
        deliveryLat != null &&
        deliveryLng != null &&
        deliveryLat.isFinite &&
        deliveryLng.isFinite &&
        deliveryLat.abs() <= 90 &&
        deliveryLng.abs() <= 180;

    const market = LatLng(
      FeeConfig.deliveryOriginLat,
      FeeConfig.deliveryOriginLng,
    );
    final delivery = hasDeliveryCoords
        ? LatLng(deliveryLat, deliveryLng)
        : null;
    // ponytail: milestone positions on a straight line; replace with rider GPS
    // and routing data when live location tracking is available.
    final progress = switch (order.status) {
      OrderStatus.confirmed || OrderStatus.preparing => 0.0,
      OrderStatus.ready => 0.25,
      OrderStatus.outForDelivery => 0.65,
      OrderStatus.completed => 1.0,
      _ => null,
    };

    // Compute distance for badge
    String distanceLabel;
    if (isPickup) {
      distanceLabel = '—';
    } else if (delivery != null) {
      final km = const Distance().as(LengthUnit.Kilometer, market, delivery);
      distanceLabel = '${km.toStringAsFixed(1)} km';
    } else {
      distanceLabel = 'Unavailable';
    }

    // Non-interactive map: market + delivery line
    final showMap = hasDeliveryCoords || isPickup;

    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (showMap)
              FlutterMap(
                options: MapOptions(
                  initialCenter: hasDeliveryCoords
                      ? LatLng(
                          (market.latitude + delivery!.latitude) / 2,
                          (market.longitude + delivery.longitude) / 2,
                        )
                      : market,
                  initialZoom: hasDeliveryCoords ? 13 : 15,
                  initialCameraFit:
                      !isPickup && delivery != null && delivery != market
                      ? CameraFit.bounds(
                          bounds: LatLngBounds(market, delivery),
                          padding: const EdgeInsets.fromLTRB(45, 80, 45, 85),
                          maxZoom: 16,
                        )
                      : null,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    fallbackUrl:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.palengkego.app',
                    panBuffer: 0,
                    keepBuffer: 3,
                    tileBuilder: (context, tileWidget, tile) {
                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: tile.loadError ? 0.3 : 1.0,
                        child: tileWidget,
                      );
                    },
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        '© OpenStreetMap contributors',
                        onTap: () {},
                      ),
                    ],
                  ),
                  PolylineLayer(
                    polylines: [
                      if (!isPickup && delivery != null)
                        Polyline(
                          points: [market, delivery],
                          strokeWidth: 4,
                          color: AppTheme.primaryGreen,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      const Marker(
                        point: market,
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.store_rounded,
                          color: AppTheme.primaryGreen,
                          size: 28,
                        ),
                      ),
                      if (!isPickup && delivery != null)
                        Marker(
                          point: delivery,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFFD97706),
                            size: 32,
                          ),
                        ),
                      if (!isPickup && delivery != null && progress != null)
                        Marker(
                          point: LatLng(
                            market.latitude +
                                (delivery.latitude - market.latitude) *
                                    progress,
                            market.longitude +
                                (delivery.longitude - market.longitude) *
                                    progress,
                          ),
                          width: 38,
                          height: 38,
                          child: Tooltip(
                            message: 'Delivery progress: ${order.status.label}',
                            child: const CircleAvatar(
                              backgroundColor: AppTheme.primaryGreen,
                              child: Icon(
                                Icons.two_wheeler,
                                color: Colors.white,
                                size: 25,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFD9FBE6), Color(0xFFE9F7EF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CustomPaint(
                  painter: _MapGridPainter(),
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned(
              top: 12,
              left: 12,
              child: _MapBadge(
                label: isPickup ? 'ESTIMATED READY TIME' : 'ESTIMATED ARRIVAL',
                value: (() {
                  if (order.status == OrderStatus.cancelled ||
                      order.status == OrderStatus.rejected) {
                    return 'Cancelled';
                  }
                  if (order.status == OrderStatus.completed) return 'Completed';
                  if (order.estimatedReadyTime != null) {
                    final diff = order.estimatedReadyTime!
                        .difference(DateTime.now())
                        .inMinutes;
                    return diff > 0 ? '$diff mins' : 'Ready';
                  }
                  return 'TBD';
                })(),
              ),
            ),
            if (!isPickup)
              Positioned(
                top: 12,
                right: 12,
                child: _MapBadge(label: 'DISTANCE', value: distanceLabel),
              ),
            if (!showMap)
              const Center(
                child: Icon(
                  Icons.location_on,
                  size: 48,
                  color: AppTheme.primaryGreen,
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
                  isPickup
                      ? "Market: Naga City People's Mall, Abella"
                      : "Delivering to: ${order.deliveryAddress ?? 'Delivery address unavailable'}\n${hasDeliveryCoords ? 'Status-based progress • Straight-line distance' : 'Delivery map pin unavailable'}",
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

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
