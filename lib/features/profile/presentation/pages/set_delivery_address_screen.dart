import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
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

  /// Height of the floating "Move pin to adjust" bubble + gap + pin icon.
  static const double _pinStackHeight = 96;

  late final MapController _mapController = MapController();
  late final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  LatLng _center = _nagaCenter;
  String _reverseAddress = 'Magsaysay Ave, Naga City';
  String _reverseStreetAddress = '';
  String _reverseBarangay = '';
  Timer? _debounce;
  Timer? _sheetDebounce;
  StreamSubscription<Position>? _locationSubscription;
  int _geocodeRequest = 0;
  LatLng? _deviceLocation;
  bool _hasPickedLocation = false;
  bool _followDeviceLocation = false;
  bool _locationUnavailable = false;
  bool _mapReady = false;

  /// Last known full height of the map area (updated in build).
  double _mapHeight = 0;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is DeliveryAddress &&
          args.latitude != null &&
          args.longitude != null) {
        final latLng = LatLng(args.latitude!, args.longitude!);
        setState(() {
          _deviceLocation = latLng;
          _followDeviceLocation = true;
        });
        _moveTo(latLng);
        _trackDeviceLocation();
      } else if (args is DeliveryAddress &&
          args.label.toLowerCase() == 'current location') {
        setState(() => _locationUnavailable = false);
        _moveToCurrentLocation();
      } else {
        // Start in manual mode. Only show the location-off banner after a
        // location request actually fails.
      }
    });
  }

  final Map<String, (String, String, String)> _geocodeCache = {};
  bool _isGeocoding = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _sheetDebounce?.cancel();
    _locationSubscription?.cancel();
    _sheetController.removeListener(_onSheetChanged);
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  double get _sheetExtent => _sheetController.isAttached
      ? _sheetController.size
      : AddressSheetSizes.initial;

  /// Y position (from the top of the map) of the pin tip: the middle of the
  /// part of the map that is not covered by the bottom sheet.
  double _pinTipY([double? extent]) {
    final visible = _mapHeight * (1 - (extent ?? _sheetExtent));
    // Keep the pin below the header even when the sheet is fully expanded.
    return math.max(visible / 2 + 24, _pinStackHeight + 64);
  }

  /// Offset (from the map's view center) where the selected point should sit.
  Offset get _pinOffset => Offset(0, _pinTipY() - _mapHeight / 2);

  LatLng _latLngUnderPin(MapCamera cam) => cam.screenOffsetToLatLng(
        Offset(cam.nonRotatedSize.width / 2, _pinTipY()),
      );

  void _onSheetChanged() {
    // The pin moves with the sheet, so the location under it changes too.
    if (!_mapReady || _mapHeight <= 0) return;
    // The sheet can notify during layout; defer the rebuild if so.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
    _sheetDebounce?.cancel();
    _sheetDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final c = _latLngUnderPin(_mapController.camera);
      if (const Distance().as(LengthUnit.Meter, c, _center) < 5) return;
      setState(() => _center = c);
      _reverseGeocode(c);
    });
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
    _hasPickedLocation = true;
    final c = _latLngUnderPin(cam);
    setState(() => _center = c);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _reverseGeocode(c));
  }

  void _moveTo(
    LatLng p, {
    bool reverseGeocode = true,
    bool markPicked = false,
  }) {
    if (_mapReady) {
      _mapController.move(p, 16, offset: _pinOffset);
    }
    setState(() => _center = p);
    if (markPicked) _hasPickedLocation = true;
    if (reverseGeocode) _reverseGeocode(p);
  }

  Future<void> _moveToCurrentLocation() async {
    if (mounted) setState(() => _locationUnavailable = false);
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
    if (moveMap) _moveTo(location, markPicked: true);
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
          _mapHeight = constraints.maxHeight;
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
                    onMapReady: () {
                      _mapReady = true;
                      _mapController.move(_center, 16, offset: _pinOffset);
                    },
                    onPositionChanged: _onPositionChanged,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
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

              // Center Pin — tip sits in the middle of the visible (uncovered) map area
              Positioned(
                left: 0,
                right: 0,
                top: _pinTipY() - _pinStackHeight,
                height: _pinStackHeight + 10,
                child: IgnorePointer(child: _buildPin()),
              ),

              // Header — white pill so the title stays readable on the map
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(4, 4, 18, 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: AppTheme.surfaceContainerLow,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => Navigator.pop(context),
                              child: const SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 16,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Set Delivery Address',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Floating Recenter Button — anchored right above the bottom sheet
              Positioned(
                bottom: math.min(
                  constraints.maxHeight - 72,
                  constraints.maxHeight * _sheetExtent + 12,
                ),
                right: 16,
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

              // Draggable Bottom Sheet — full width, solid white, sticky confirm button
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: AddressSheetSizes.initial,
                minChildSize: AddressSheetSizes.min,
                maxChildSize: AddressSheetSizes.max,
                snap: true,
                snapSizes: AddressSheetSizes.snaps,
                snapAnimationDuration: const Duration(milliseconds: 240),
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: DeliveryAddressFormSheet(
                      scrollController: scrollController,
                      sheetController: _sheetController,
                      selectedLocation: _center,
                      hasPickedLocation: _hasPickedLocation,
                      reverseAddress: _reverseAddress,
                      reverseStreetAddress: _reverseStreetAddress,
                      reverseBarangay: _reverseBarangay,
                      onMoveMap: (point) {
                        _followDeviceLocation = false;
                        _moveTo(point, reverseGeocode: false, markPicked: true);
                      },
                      locationUnavailable: _locationUnavailable,
                      onRetryLocation: _moveToCurrentLocation,
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

  Widget _buildPin() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                _isGeocoding ? 'Locating address...' : 'Move pin to adjust',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // The tip of `location_on` is ~4px above the icon's bottom edge;
        // the Positioned height accounts for this so the tip lands on _pinTipY.
        const Icon(
          Icons.location_on,
          size: 48,
          color: AppTheme.primaryGreen,
        ),
        Container(
          width: 16,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
