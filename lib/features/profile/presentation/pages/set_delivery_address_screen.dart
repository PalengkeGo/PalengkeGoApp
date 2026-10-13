import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
  late final MapController _mapController = MapController();
  late final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  LatLng _center = _nagaCenter;
  String _reverseAddress = 'Magsaysay Ave, Naga City';
  String _reverseStreetAddress = '';
  String _reverseBarangay = '';
  Timer? _debounce;
  StreamSubscription<Position>? _locationSubscription;
  int _geocodeRequest = 0;
  LatLng? _deviceLocation;
  bool _followDeviceLocation = false;
  bool _locationUnavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is DeliveryAddress &&
          args.latitude != null &&
          args.longitude != null) {
        final latLng = LatLng(args.latitude!, args.longitude!);
        setState(() {
          _center = latLng;
          _deviceLocation = latLng;
          _followDeviceLocation = true;
        });
        _mapController.move(latLng, 16);
        _reverseGeocode(latLng);
        _trackDeviceLocation();
      } else if (args is DeliveryAddress &&
          args.label.toLowerCase() == 'current location') {
        setState(() => _locationUnavailable = false);
        _moveToCurrentLocation();
      } else {
        setState(() => _locationUnavailable = true);
        _reverseGeocode(_center);
      }
    });
  }

  final Map<String, (String, String, String)> _geocodeCache = {};
  bool _isGeocoding = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _locationSubscription?.cancel();
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng p) async {
    final request = ++_geocodeRequest;
    final cacheKey =
        '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';
    if (_geocodeCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          final cached = _geocodeCache[cacheKey]!;
          _reverseAddress = cached.$1;
          _reverseStreetAddress = cached.$2;
          _reverseBarangay = cached.$3;
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
        if (display != null && mounted && request == _geocodeRequest) {
          final address = data['address'] as Map<String, dynamic>? ?? {};
          final road = address['road'] as String? ??
              address['pedestrian'] as String? ??
              address['residential'] as String? ?? '';
          final houseNumber = address['house_number'] as String? ?? '';
          final street = [houseNumber, road].where((part) => part.isNotEmpty).join(' ');
          final barangay = address['suburb'] as String? ??
              address['neighbourhood'] as String? ??
              address['village'] as String? ??
              address['quarter'] as String? ?? '';
          _geocodeCache[cacheKey] = (display, street, barangay);
          setState(() {
            _reverseAddress = display;
            _reverseStreetAddress = street;
            _reverseBarangay = barangay;
            _isGeocoding = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted && request == _geocodeRequest) {
      setState(() {
        _isGeocoding = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address lookup failed. Enter the address manually.')),
      );
    }
  }

  void _onPositionChanged(MapCamera cam, bool hasGesture) {
    if (!hasGesture) return;
    _followDeviceLocation = false;
    final c = cam.center;
    setState(() => _center = c);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _reverseGeocode(c));
  }

  void _moveTo(LatLng p) {
    _mapController.move(p, 16);
    setState(() => _center = p);
    _reverseGeocode(p);
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Allow location access to find your position.');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 12));
      setState(() {
        _locationUnavailable = false;
        _followDeviceLocation = true;
      });
      _updateDevicePosition(pos, moveMap: true);
      _trackDeviceLocation();
    } catch (e) {
      if (mounted) {
        setState(() => _locationUnavailable = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to get your location: $e')),
        );
      }
    }
  }

  void _trackDeviceLocation() {
    _locationSubscription?.cancel();
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (position) => _updateDevicePosition(
        position,
        moveMap: _followDeviceLocation,
      ),
      onError: (_) {
        if (mounted) setState(() => _locationUnavailable = true);
      },
    );
  }

  void _updateDevicePosition(Position position, {required bool moveMap}) {
    if (!mounted) return;
    final location = LatLng(position.latitude, position.longitude);
    setState(() => _deviceLocation = location);
    if (moveMap) _moveTo(location);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 200 || constraints.maxWidth < 150) {
            return const SizedBox.shrink();
          }
          return Stack(
            children: [
              // Full-screen Map — covers the entire background so dragging sheet reveals the full map
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15,
                    minZoom: 12,
                    maxZoom: 18,
                    onPositionChanged: _onPositionChanged,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
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
                    if (_deviceLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _deviceLocation!,
                            width: 22,
                            height: 22,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2878F0),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          '© OpenStreetMap contributors',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Floating Recenter Button — smoothly anchored right above the bottom sheet
              AnimatedBuilder(
                animation: _sheetController,
                builder: (context, child) {
                  final extent = _sheetController.isAttached
                      ? _sheetController.size
                      : 0.42;
                  final bottomPos = math.min(
                    constraints.maxHeight - 72,
                    math.max(16.0, (constraints.maxHeight * extent) + 16.0),
                  );
                  return Positioned(
                    bottom: bottomPos,
                    right: 16,
                    child: child!,
                  );
                },
                child: Material(
                  elevation: 4,
                  shape: const CircleBorder(),
                  color: Colors.white,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _moveToCurrentLocation,
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

              // Location unavailable info banner
              if (_locationUnavailable)
                Positioned(
                  top: 72,
                  left: 16,
                  right: 16,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 2,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Location unavailable. Move the pin or enter your address manually below.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                      ),
                    ),
                  ),
                ),

              // Center Pin — tip (bottom of icon) exactly at map center (screen center)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -24),
                      child: OverflowBox(
                        minWidth: 0,
                        maxWidth: double.infinity,
                        minHeight: 0,
                        maxHeight: double.infinity,
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

              // Draggable Bottom Sheet with snapping & mouse/touch drag support
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: 0.42,
                minChildSize: 0.12,
                maxChildSize: 0.85,
                snap: true,
                snapSizes: const [0.12, 0.42, 0.85],
                snapAnimationDuration: const Duration(milliseconds: 240),
                builder: (context, scrollController) {
                  return ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                    ),
                    child: Padding(
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
                              sheetController: _sheetController,
                              selectedLocation: _center,
                              reverseAddress: _reverseAddress,
                              reverseStreetAddress: _reverseStreetAddress,
                              reverseBarangay: _reverseBarangay,
                              onMoveMap: _moveTo,
                            ),
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
