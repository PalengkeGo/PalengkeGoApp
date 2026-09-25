import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';
import 'package:palengkego/features/profile/presentation/widgets/delivery_address_form_sheet.dart';

class SetDeliveryAddressScreen extends ConsumerStatefulWidget {
  const SetDeliveryAddressScreen({super.key});

  @override
  ConsumerState<SetDeliveryAddressScreen> createState() =>
      _SetDeliveryAddressScreenState();
}

class _SetDeliveryAddressScreenState
    extends ConsumerState<SetDeliveryAddressScreen> {
  static const _nagaCenter = LatLng(
    FeeConfig.deliveryOriginLat,
    FeeConfig.deliveryOriginLng,
  );
  static final _nagaBounds = LatLngBounds(
    const LatLng(13.55, 123.12),
    const LatLng(13.69, 123.28),
  );

  late final MapController _mapController = MapController();
  LatLng _center = _nagaCenter;
  String _reverseAddress = 'Magsaysay Ave, Naga City';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is DeliveryAddress &&
          args.latitude != null &&
          args.longitude != null) {
        final latLng = LatLng(args.latitude!, args.longitude!);
        setState(() => _center = latLng);
        _mapController.move(latLng, 16);
        _reverseGeocode(latLng);
      }
    });
  }

  final Map<String, String> _geocodeCache = {};
  bool _isGeocoding = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng p) async {
    final cacheKey =
        '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';
    if (_geocodeCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _reverseAddress = _geocodeCache[cacheKey]!;
          _isGeocoding = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isGeocoding = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${p.latitude}&lon=${p.longitude}&zoom=18&addressdetails=1',
      );
      final resp = await http.get(
        uri,
        headers: kIsWeb
            ? {}
            : {'User-Agent': 'PalengkeGo/1.0 (contact: palengkego@example.com)'},
      ).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final display = data['display_name'] as String?;
        if (display != null && mounted) {
          final shortAddr = display.split(',').take(4).join(', ');
          _geocodeCache[cacheKey] = shortAddr;
          setState(() {
            _reverseAddress = shortAddr;
            _isGeocoding = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isGeocoding = false);
  }

  void _onPositionChanged(MapCamera cam, bool hasGesture) {
    if (!hasGesture) return;
    final c = cam.center;
    // Clamp to Naga bounds
    final clamped = LatLng(
      c.latitude.clamp(_nagaBounds.southWest.latitude, _nagaBounds.northEast.latitude),
      c.longitude.clamp(_nagaBounds.southWest.longitude, _nagaBounds.northEast.longitude),
    );
    setState(() => _center = clamped);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _reverseGeocode(clamped));
  }

  void _moveTo(LatLng p) {
    _mapController.move(p, 16);
    setState(() => _center = p);
    _reverseGeocode(p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          const bottomSheetHeight = 420.0;
          const headerHeight = 60.0;
          const visibleMapTop = headerHeight;
          final visibleMapBottom = constraints.maxHeight - bottomSheetHeight;
          return Stack(
            children: [
              // Real map — only visible area (above sheet) so tip = center
              Positioned(
                top: visibleMapTop,
                height: visibleMapBottom - visibleMapTop,
                left: 0,
                right: 0,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15,
                    minZoom: 12,
                    maxZoom: 18,
                    cameraConstraint: CameraConstraint.contain(bounds: _nagaBounds),
                    onPositionChanged: _onPositionChanged,
                  ),
                  children: [
                    TileLayer(
                      // CARTO Voyager CDN with 4 parallel edge subdomains for ultra-fast loading in PH
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      fallbackUrl:
                          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName:
                          'PalengkeGo/1.0 (contact: palengkego@example.com)',
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
                          '© OpenStreetMap contributors, © CARTO',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Floating Recenter Button
              Positioned(
                top: visibleMapBottom - 56,
                right: 16,
                child: Material(
                  elevation: 4,
                  shape: const CircleBorder(),
                  color: Colors.white,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _moveTo(const LatLng(13.6218, 123.1948)),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.my_location_rounded,
                        size: 22,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ),
              ),

              // Center Pin — tip (bottom of icon) exactly at map center
              Positioned(
                top: visibleMapTop,
                height: visibleMapBottom - visibleMapTop,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isGeocoding) ...[
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  _isGeocoding
                                      ? 'Locating address...'
                                      : 'Move pin to adjust',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Icon(
                            Icons.location_on,
                            size: 48,
                            color: AppTheme.primaryGreen,
                          ),
                          Container(
                            width: 20,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Header
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Set Delivery Address',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Draggable Bottom Sheet
              DraggableScrollableSheet(
                initialChildSize: 0.45,
                minChildSize: 0.2,
                maxChildSize: 0.8,
                builder: (context, scrollController) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: kIsWeb ? 0.1 : 12,
                          sigmaY: kIsWeb ? 0.1 : 12,
                        ),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          decoration: BoxDecoration(
                            color: kIsWeb
                                ? const Color(
                                    0xFFE8F4F8,
                                  ).withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.18),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: kIsWeb ? 0.6 : 0.35,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: DeliveryAddressFormSheet(
                            scrollController: scrollController,
                            selectedLocation: _center,
                            reverseAddress: _reverseAddress,
                            onMoveMap: _moveTo,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
