import 'package:palengkego/core/theme/app_theme.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:palengkego/features/profile/presentation/widgets/delivery_address_form_sheet.dart';
import 'package:palengkego/features/profile/presentation/widgets/delivery_address_map_background.dart';

class SetDeliveryAddressScreen extends ConsumerStatefulWidget {
  const SetDeliveryAddressScreen({super.key});

  @override
  ConsumerState<SetDeliveryAddressScreen> createState() =>
      _SetDeliveryAddressScreenState();
}

class _SetDeliveryAddressScreenState extends ConsumerState<SetDeliveryAddressScreen> {
  final MapController _mapController = MapController();
  LatLng _selectedLocation = const LatLng(13.6220, 123.2137); // Naga City default
  bool _mapReady = false;
  Timer? _dragDebounce;
  // Registered by DeliveryAddressFormSheet via onPinMovedRegister
  void Function(double lat, double lng)? _onPinMoved;

  /// Geometry of the map widget + the pin-tip anchor line, refreshed in build.
  /// The map fills the whole body but the bottom sheet covers part of it, so
  /// the coordinate "under the pin" is NOT the raw camera center — it is the
  /// screen point where the pin tip sits. We always convert that exact point.
  double _mapWidth = 0;
  double _pinTipY = 0;

  void _onMapReady(LatLng center) {
    final cam = _mapController.camera;
    final pinLocation =
        (cam.size.shortestSide > 0 && _pinTipY > 0)
            ? cam.screenOffsetToLatLng(Offset(_mapWidth / 2, _pinTipY))
            : center;
    setState(() {
      _selectedLocation = pinLocation;
      _mapReady = true;
    });
    // Try to center on the device's current location.
    _locateMe();
  }

  void _onLocationSearched(double lat, double lng, String addressName) {
    // Move the camera so the searched place lands exactly under the pin tip.
    _centerOnLatLng(LatLng(lat, lng), 17.0);
  }

  /// Moves the map so [target] appears under the pin tip (the visible map
  /// area's center), instead of at the raw widget center which sits behind
  /// the bottom sheet. Rotation is disabled, so this is a pure translation
  /// and the pixel math is exact.
  void _centerOnLatLng(LatLng target, double zoom) {
    final cam = _mapController.camera;
    if (cam.size.shortestSide <= 0 || !_mapReady) {
      _mapController.move(target, zoom);
      return;
    }
    final pinPoint = Offset(_mapWidth / 2, _pinTipY);
    final targetScreen = cam.latLngToScreenOffset(target);
    final shift = pinPoint - targetScreen;
    _mapController.move(
      cam.screenOffsetToLatLng(
        Offset(
          cam.size.width / 2 + shift.dx,
          cam.size.height / 2 + shift.dy,
        ),
      ),
      zoom,
    );
  }

  /// Requests location permission and moves the map to the device location.
  Future<void> _locateMe() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable your device location services.'),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to use this.'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final target = LatLng(position.latitude, position.longitude);
      // Center the camera so the GPS coordinate lands exactly under the pin.
      _centerOnLatLng(target, 16.5);
      // onPositionChanged fires after the move and reverse-geocodes the pin point.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location found — review the address below, '
            'then tap "Confirm Address" to save.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Failed to get current location: $e');
    }
  }

  @override
  void dispose() {
    _dragDebounce?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive geometry: the bottom sheet starts at 45% of the screen
          // height (matches DraggableScrollableSheet.initialChildSize) and the
          // header is sized from the real status bar + toolbar, so the math
          // holds on any phone size.
          final topSafe = MediaQuery.paddingOf(context).top;
          const headerInnerHeight = 8.0 + 40.0; // header padding-top + row height
          final visibleMapTop = topSafe + headerInnerHeight;
          final sheetHeight = constraints.maxHeight * 0.45;
          final visibleMapBottom = constraints.maxHeight - sheetHeight;
          final visibleMapCenter = (visibleMapTop + visibleMapBottom) / 2;
          _mapWidth = constraints.maxWidth;
          _pinTipY = visibleMapCenter;

          return Stack(
            children: [
              // Map Background - Interactive OpenStreetMap
              DeliveryAddressMapBackground(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                mapController: _mapController,
                initialCenter: _selectedLocation,
                onMapReady: _onMapReady,
                onPositionChanged: (camera, hasGesture) {
                  // The pin tip sits at (_mapWidth/2, _pinTipY); resolve the
                  // exact coordinate under it (NOT the raw camera center,
                  // which lies behind the bottom sheet).
                  _selectedLocation = camera.screenOffsetToLatLng(
                    Offset(_mapWidth / 2, _pinTipY),
                  );
                  // Defer setState to avoid calling it during FlutterMap's
                  // initial build phase.
                  if (SchedulerBinding.instance.schedulerPhase ==
                      SchedulerPhase.idle) {
                    setState(() {});
                  } else {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() {});
                    });
                  }
                  // Standard debounce: fire reverse-geocode 300 ms after
                  // the LAST camera change, whether from a drag, fling, or
                  // programmatic move (search).
                  _dragDebounce?.cancel();
                  _dragDebounce = Timer(const Duration(milliseconds: 300), () {
                    _onPinMoved?.call(
                      _selectedLocation.latitude,
                      _selectedLocation.longitude,
                    );
                  });
                },
              ),

              // Center Pin - anchored so its TIP lands exactly on the visible
              // map center (the same point that gets reverse-geocoded).
              Positioned(
                left: 0,
                right: 0,
                top: visibleMapTop,
                height: (visibleMapCenter - visibleMapTop).clamp(0, 1e9),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tooltip above the pin (skipped when the visible map
                      // area is too short, e.g. very small phones).
                      if (visibleMapCenter - visibleMapTop > 130)
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
                          child: const Text(
                            'Move map to adjust',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      if (visibleMapCenter - visibleMapTop > 130)
                        const SizedBox(height: 8),
                      // Pin icon: the tip (bottom of the icon) = anchor line.
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 48,
                              color: AppTheme.primaryGreen,
                            ),
                            // Pin shadow at the tip
                            Positioned(
                              bottom: 1,
                              child: Container(
                                width: 20,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

              // Current location indicator
              if (_mapReady)
                Positioned(
                  bottom: sheetHeight + 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.my_location,
                          size: 16,
                          color: AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedLocation.latitude.toStringAsFixed(6)}, '
                          '${_selectedLocation.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Use-current-location pill button
              if (_mapReady)
                Positioned(
                  bottom: sheetHeight + 16,
                  right: 16,
                  child: Material(
                    color: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 3,
                    shadowColor: Colors.black.withValues(alpha: 0.15),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: _locateMe,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location,
                              size: 18,
                              color: AppTheme.primaryGreen,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Use Current Location',
                              style: TextStyle(
                                fontSize: 13,
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
                            initialLatitude: _selectedLocation.latitude,
                            initialLongitude: _selectedLocation.longitude,
                            onLocationSearched: _onLocationSearched,
                            onPinMovedRegister: (cb) => _onPinMoved = cb,
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
