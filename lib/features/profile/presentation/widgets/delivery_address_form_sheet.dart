import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

class DeliveryAddressFormSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final double? initialLatitude;
  final double? initialLongitude;
  final void Function(double lat, double lng, String addressName)?
  onLocationSearched;
  final void Function(void Function(double lat, double lng))?
  onPinMovedRegister;

  const DeliveryAddressFormSheet({
    super.key,
    required this.scrollController,
    this.initialLatitude,
    this.initialLongitude,
    this.onLocationSearched,
    this.onPinMovedRegister,
  });

  @override
  ConsumerState<DeliveryAddressFormSheet> createState() =>
      _DeliveryAddressFormSheetState();
}

class _DeliveryAddressFormSheetState
    extends ConsumerState<DeliveryAddressFormSheet> {
  final _labelController = TextEditingController();
  final _primaryAddressController = TextEditingController();
  final _streetAddressController = TextEditingController();
  final _notesController = TextEditingController();
  IconData? _selectedCustomIcon;

  static const _addressIconList = [
    Icons.home_outlined,
    Icons.work_outline_rounded,
    Icons.school_outlined,
    Icons.favorite_outline_rounded,
    Icons.lock_outline_rounded,
    Icons.star_outline_rounded,
    Icons.fitness_center_rounded,
    Icons.local_cafe_outlined,
  ];

  static IconData _iconForCodePoint(int codePoint) {
    for (final icon in _addressIconList) {
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.favorite_rounded;
  }

  static const List<String> _nagaBarangays = [
    'Abella',
    'Bagumbayan Norte',
    'Bagumbayan Sur',
    'Calauag',
    'Cararayan',
    'Carolina',
    'Concepcion Grande',
    'Concepcion Pequeña',
    'Dayangdang',
    'Del Rosario',
    'Dinaga',
    'Igualdad Interior',
    'Lerma',
    'Liboton',
    'Mabolo',
    'Pacol',
    'Panicuason',
    'Peñafrancia',
    'Sabang',
    'San Felipe',
    'San Francisco',
    'San Isidro',
    'Santa Cruz',
    'Tabuco',
    'Tinago',
    'Triangulo',
  ];

  static const Map<String, Map<String, double>> _nagaLandmarks = {
    'SM City Naga': {'lat': 13.6218, 'lng': 123.1895},
    'Plaza Quince Martires': {'lat': 13.6241, 'lng': 123.1852},
    'Naga City People\'s Mall': {'lat': 13.6212, 'lng': 123.1837},
    'Naga Metropolitan Cathedral': {'lat': 13.6267, 'lng': 123.1858},
    'Avenue Plaza Hotel': {'lat': 13.6315, 'lng': 123.1956},
    'Universidad de Santa Isabel': {'lat': 13.6254, 'lng': 123.1868},
    'Ateneo de Naga University': {'lat': 13.6300, 'lng': 123.1885},
    'University of Nueva Caceres (UNC)': {'lat': 13.6205, 'lng': 123.1878},
    'Robinsons Place Naga': {'lat': 13.6166, 'lng': 123.1990},
    'Bicol Medical Center (BMC)': {'lat': 13.6292, 'lng': 123.1983},
    'Jesse M. Robredo Museum': {'lat': 13.6295, 'lng': 123.1944},
    'Magsaysay Avenue': {'lat': 13.6305, 'lng': 123.1945},
    'Bagumbayan Norte': {'lat': 13.6350, 'lng': 123.1860},
    'Bagumbayan Sur': {'lat': 13.6310, 'lng': 123.1830},
    'Concepcion Pequeña': {'lat': 13.6220, 'lng': 123.2050},
    'Concepcion Grande': {'lat': 13.6180, 'lng': 123.2180},
    'Del Rosario': {'lat': 13.6080, 'lng': 123.2250},
    'San Felipe': {'lat': 13.6380, 'lng': 123.2000},
    'Peñafrancia': {'lat': 13.6320, 'lng': 123.1900},
    'Triangulo': {'lat': 13.6190, 'lng': 123.1920},
    'Tabuco': {'lat': 13.6180, 'lng': 123.1840},
    'Sabang': {'lat': 13.6220, 'lng': 123.1800},
    'STI College Naga': {'lat': 13.6229, 'lng': 123.1920},
    'Landers Superstore Naga': {'lat': 13.6180, 'lng': 123.1970},
    'S&R Membership Shopping Naga': {'lat': 13.6170, 'lng': 123.1960},
    'Naga Grand Mall': {'lat': 13.6235, 'lng': 123.1865},
    'Fuente Osmeña Circle': {'lat': 13.6242, 'lng': 123.1878},
    'Naga City Hall': {'lat': 13.6250, 'lng': 123.1855},
    'Holy Rosary Minor Seminary': {'lat': 13.6295, 'lng': 123.1890},
    'CBD Mall': {'lat': 13.6245, 'lng': 123.1870},
    'Animasola Shrine': {'lat': 13.6265, 'lng': 123.1860},
  };

  static const Map<String, Map<String, double>> _nagaBarangayCoords = {
    'Abella': {'lat': 13.6283, 'lng': 123.1917},
    'Calauag': {'lat': 13.6200, 'lng': 123.2030},
    'Cararayan': {'lat': 13.6135, 'lng': 123.2155},
    'Carolina': {'lat': 13.6110, 'lng': 123.2085},
    'Dayangdang': {'lat': 13.6190, 'lng': 123.1960},
    'Dinaga': {'lat': 13.6250, 'lng': 123.1890},
    'Igualdad Interior': {'lat': 13.6245, 'lng': 123.1875},
    'Lerma': {'lat': 13.6295, 'lng': 123.1830},
    'Liboton': {'lat': 13.6300, 'lng': 123.1810},
    'Mabolo': {'lat': 13.6160, 'lng': 123.2100},
    'Pacol': {'lat': 13.6100, 'lng': 123.2250},
    'Panicuason': {'lat': 13.5950, 'lng': 123.2200},
    'San Francisco': {'lat': 13.6340, 'lng': 123.1930},
    'San Isidro': {'lat': 13.6360, 'lng': 123.2070},
    'Santa Cruz': {'lat': 13.6225, 'lng': 123.2005},
    'Tinago': {'lat': 13.6255, 'lng': 123.1950},
  };
  static (String, double)? _findNearestKnownPlace(double lat, double lng) {
    // Landmarks are mapped to tile-accurate coordinates, so trust them up to
    // ~300 m. Barangay centers are coarser estimates — only claim one when the
    // pin is essentially on top of it, otherwise fall through to the OSM
    // road address instead of guessing wrong.
    String best = '';
    double bestDist = 300;
    for (final e in _nagaLandmarks.entries) {
      final d = Geolocator.distanceBetween(
        lat,
        lng,
        e.value['lat']!,
        e.value['lng']!,
      );
      if (d < bestDist) {
        bestDist = d;
        best = e.key;
      }
    }
    if (best.isNotEmpty) return (best, bestDist);
    for (final e in _nagaBarangayCoords.entries) {
      final d = Geolocator.distanceBetween(
        lat,
        lng,
        e.value['lat']!,
        e.value['lng']!,
      );
      if (d < 100) return (e.key, d);
    }
    return null;
  }

  static String _distLabel(double meters) => meters < 1000
      ? '${meters.round()}m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

  static ({String primary, String street}) _parseNominat(
    Map<String, dynamic> data,
  ) {
    final addr = data['address'] as Map<String, dynamic>? ?? {};
    // Deliberately IGNORE Nominatim's POI/name fields here: OSM nodes in Naga
    // are sparse/imprecise and routinely name the *nearest* node (e.g. a
    // Jollibee a block away), which made the text disagree with the pin. Known
    // POIs are covered locally by `_nagaLandmarks`; everywhere else the road
    // + baranggay address is the accurate answer.
    final road = (addr['road'] ?? addr['pedestrian'] ?? addr['footway'] ?? '')
        .toString();
    final houseNumber = (addr['house_number'] ?? '').toString();
    final neighbourhood = (addr['neighbourhood'] ?? '').toString();
    final suburb = (addr['suburb'] ?? addr['village'] ?? '').toString();
    final city =
        (addr['city'] ?? addr['town'] ?? addr['municipality'] ?? 'Naga City')
            .toString();

    final primary = [
      road,
      neighbourhood,
      suburb,
      city,
    ].where((s) => s.isNotEmpty).join(', ');

    final streetParts = <String>[
      if (houseNumber.isNotEmpty && road.isNotEmpty) '$houseNumber $road',
      if (houseNumber.isEmpty && road.isNotEmpty) road,
      if (suburb.isNotEmpty) 'Brgy. $suburb',
      if (neighbourhood.isNotEmpty && neighbourhood != suburb)
        'Brgy. $neighbourhood',
      city,
    ];
    final street = streetParts.where((s) => s.isNotEmpty).join(', ');

    return (primary: primary, street: street);
  }

  bool _isSearching = false;
  Future<void> _geocodeAndMoveTo(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    for (final entry in _nagaLandmarks.entries) {
      if (entry.key.toLowerCase().contains(trimmed.toLowerCase()) ||
          trimmed.toLowerCase().contains(entry.key.toLowerCase())) {
        widget.onLocationSearched?.call(
          entry.value['lat']!,
          entry.value['lng']!,
          entry.key,
        );
        return;
      }
    }

    if (mounted) setState(() => _isSearching = true);
    final cleanQuery = trimmed.toLowerCase().contains('naga')
        ? trimmed
        : '$trimmed, Naga City, Camarines Sur, Philippines';

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://nominatim.openstreetmap.org/search'
              '?q=${Uri.encodeComponent(cleanQuery)}'
              '&format=json'
              '&limit=5'
              '&countrycodes=ph'
              '&viewbox=123.13,13.70,123.27,13.54'
              '&bounded=1',
            ),
            headers: {'User-Agent': 'PalengkeGo/1.0'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat'].toString());
          final lon = double.tryParse(data[0]['lon'].toString());
          final displayName = data[0]['display_name'] ?? trimmed;
          if (lat != null && lon != null) {
            widget.onLocationSearched?.call(lat, lon, displayName);
          }
        }
      }
    } catch (e) {
      debugPrint('Forward geocoding error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final currentAddress = ref.read(preferencesProvider).deliveryAddress;
    _applyAddress(currentAddress);
    _reverseGeocodeInitialLocation();
    widget.onPinMovedRegister?.call(_reverseGeocodeAndFill);
  }

  bool _initialized = false;

  /// True when the form was pre-populated from a route-arg DeliveryAddress
  /// (editing an existing address). The initial reverse-geocode must NOT
  /// overwrite user-saved fields.
  bool _appliedFromRouteArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is DeliveryAddress) {
        _applyAddress(args);
        _appliedFromRouteArgs = true;
      }
    }
  }

  void _applyAddress(DeliveryAddress address) {
    _labelController.text = address.label == 'other' ? '' : address.label;
    _primaryAddressController.text = address.primaryAddress.isEmpty
        ? 'Magsaysay Ave, Naga City'
        : address.primaryAddress;
    _streetAddressController.text = address.streetAddress;
    _notesController.text = address.notes;
    if (address.iconCodePoint != null) {
      _selectedCustomIcon = _iconForCodePoint(address.iconCodePoint!);
    }
  }

  Future<void> _reverseGeocodeAndFill(double lat, double lng) async {
    if (!mounted) return;

    // Prefer the local landmark DB: its coordinates are tile-accurate, so the
    // named place matches what the pin points at. Nominatim streets fill in
    // the exact road/brgy line, but its guessed POI (nearest node) is NOT
    // allowed to overwrite a nearer known landmark.
    final nearest = _findNearestKnownPlace(lat, lng);
    String? localPrimary;
    if (nearest != null && mounted) {
      final (name, distM) = nearest;
      final label = distM < 60 ? name : '$name (~${_distLabel(distM)} away)';
      localPrimary = 'Near $label, Naga City';
      setState(() {
        _primaryAddressController.text = localPrimary!;
        _streetAddressController.text = '$name, Naga City';
      });
    }

    if (mounted) setState(() => _isSearching = true);
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://nominatim.openstreetmap.org/reverse'
              '?format=json'
              '&lat=$lat&lon=$lng'
              '&zoom=18&addressdetails=1'
              '&countrycodes=ph&accept-language=en',
            ),
            headers: {'User-Agent': 'PalengkeGo/1.0'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final parsed = _parseNominat(data);
        setState(() {
          // OSM supplies the precise road/barangay line; the local landmark
          // primary stays when one was found.
          if (parsed.street.isNotEmpty) {
            _streetAddressController.text = parsed.street;
          }
          if (localPrimary == null && parsed.primary.isNotEmpty) {
            _primaryAddressController.text = parsed.primary;
          }
        });
      }
    } catch (e) {
      debugPrint('Reverse geocode on pin move failed: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _reverseGeocodeInitialLocation() async {
    if (widget.initialLatitude == null || widget.initialLongitude == null) {
      return;
    }
    final lat = widget.initialLatitude!;
    final lng = widget.initialLongitude!;

    final nearest = _findNearestKnownPlace(lat, lng);
    String? localPrimary;
    if (nearest != null) {
      final (name, distM) = nearest;
      final label = distM < 60 ? name : '$name (~${_distLabel(distM)} away)';
      localPrimary = 'Near $label, Naga City';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_appliedFromRouteArgs) {
          setState(() {
            _primaryAddressController.text = localPrimary!;
            _streetAddressController.text = '$name, Naga City';
          });
        }
      });
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://nominatim.openstreetmap.org/reverse'
              '?format=json'
              '&lat=$lat&lon=$lng'
              '&zoom=18&addressdetails=1'
              '&countrycodes=ph&accept-language=en',
            ),
            headers: {'User-Agent': 'PalengkeGo/1.0'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final parsed = _parseNominat(data);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_appliedFromRouteArgs) {
            setState(() {
              // Same merge rule as _reverseGeocodeAndFill: Nominatim only
              // adds the road/brgy line and never overrides a known landmark.
              if (parsed.street.isNotEmpty) {
                _streetAddressController.text = parsed.street;
              }
              if (localPrimary == null && parsed.primary.isNotEmpty) {
                _primaryAddressController.text = parsed.primary;
              }
            });
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _labelController.dispose();
    _primaryAddressController.dispose();
    _streetAddressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.muted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.near_me,
                    size: 24,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PIN DROPPED NEAR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _primaryAddressController,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (val) => _geocodeAndMoveTo(val),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: 'Enter City/Landmark',
                          hintStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.muted,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_primaryAddressController.text.isNotEmpty)
            _buildBarangaySuggestions(_primaryAddressController),
          const SizedBox(height: 20),
          _buildInputLabel('LABEL (e.g. Home, Work, School)'),
          const SizedBox(height: 8),
          _buildLabelChips(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _labelController,
                  hintText: 'Custom Label',
                  prefixIcon: _selectedCustomIcon ?? Icons.label_outline,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _selectedCustomIcon ?? Icons.add_reaction_outlined,
                  color: AppTheme.primaryGreen,
                ),
                onPressed: () => _showIconPicker(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputLabel('STREET ADDRESS / LANDMARKS'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _streetAddressController,
            hintText: 'Unit No., Building, Street Name',
            prefixIcon: Icons.location_on_outlined,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (val) => setState(() {}),
          ),
          if (_streetAddressController.text.isNotEmpty)
            _buildBarangaySuggestions(_streetAddressController),
          const SizedBox(height: 16),
          _buildInputLabel('ADD NOTES FOR COURIER (OPTIONAL)'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _notesController,
            hintText: 'e.g. Red gate, ring the doorbell',
            prefixIcon: Icons.notes_outlined,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  DeliveryAddress(
                    label: _labelController.text.isEmpty
                        ? 'Home'
                        : _labelController.text,
                    primaryAddress: _primaryAddressController.text,
                    streetAddress: _streetAddressController.text,
                    notes: _notesController.text,
                    iconCodePoint:
                        (_selectedCustomIcon ?? Icons.favorite_rounded)
                            .codePoint,
                    // Map-pin coordinates — retained so distance-based
                    // delivery fees can be computed from this address.
                    latitude: widget.initialLatitude,
                    longitude: widget.initialLongitude,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: const Text(
                'Confirm Address',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showIconPicker(BuildContext context) {
    const icons = _addressIconList;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Label Icon',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: icons.map((icon) {
                final isSelected = _selectedCustomIcon == icon;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCustomIcon = icon;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      size: 24,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBarangaySuggestions(TextEditingController controller) {
    final query = controller.text.trim();
    if (query.length < 2) return const SizedBox.shrink();
    final queryLower = query.toLowerCase();
    final matchingBarangays = _nagaBarangays
        .where((b) => b.toLowerCase().contains(queryLower))
        .map(
          (b) => {
            'title': '$b, Naga City',
            'query': '$b, Naga City',
            'isLandmark': false,
          },
        )
        .toList();
    final matchingLandmarks = _nagaLandmarks.keys
        .where((l) => l.toLowerCase().contains(queryLower))
        .map((l) => {'title': l, 'query': l, 'isLandmark': true})
        .toList();
    final combined = [
      ...matchingLandmarks,
      ...matchingBarangays,
    ].take(5).toList();

    return Container(
      margin: const EdgeInsets.only(top: 4),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...combined.map((item) {
            final itemQuery = item['query'] as String;
            final title = item['title'] as String;
            final isLandmark = item['isLandmark'] as bool;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  controller.text = title;
                });
                _geocodeAndMoveTo(itemQuery);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      isLandmark
                          ? Icons.place_outlined
                          : Icons.near_me_outlined,
                      size: 16,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          InkWell(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            onTap: () {
              _geocodeAndMoveTo(query);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  if (_isSearching)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  else
                    const Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: AppTheme.primaryGreen,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search "$query" on Map',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelChips() {
    final predefinedLabels = <Map<String, dynamic>>[
      {'name': 'Home', 'icon': Icons.home_outlined},
      {'name': 'Work', 'icon': Icons.work_outline},
      {'name': 'School', 'icon': Icons.school_outlined},
    ];
    final currentText = _labelController.text.trim();
    if (currentText.isNotEmpty) {
      final isPredefined = predefinedLabels.any(
        (l) => l['name'].toString().toLowerCase() == currentText.toLowerCase(),
      );
      if (!isPredefined) {
        predefinedLabels.add({
          'name': currentText,
          'icon': _selectedCustomIcon ?? Icons.favorite_border_rounded,
        });
      }
    }
    try {
      final savedAddresses = ref.watch(preferencesProvider).savedAddresses;
      for (final addr in savedAddresses) {
        final label = addr.label.trim();
        if (label.isNotEmpty) {
          final exists = predefinedLabels.any(
            (l) => l['name'].toString().toLowerCase() == label.toLowerCase(),
          );
          if (!exists) {
            predefinedLabels.add({
              'name': label,
              'icon': _iconForCodePoint(
                addr.iconCodePoint ?? Icons.favorite_outline_rounded.codePoint,
              ),
            });
          }
        }
      }
    } catch (_) {}
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: predefinedLabels.map((label) {
        final labelName = label['name'] as String;
        final isSelected =
            _labelController.text.trim().toLowerCase() ==
            labelName.toLowerCase();
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ChoiceChip(
            label: Text(labelName),
            avatar: Icon(
              label['icon'] as IconData,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.primaryGreen,
            ),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _labelController.text = selected ? labelName : '';
                if (selected &&
                    !(label['name'] == 'Home' ||
                        label['name'] == 'Work' ||
                        label['name'] == 'School')) {
                  _selectedCustomIcon = label['icon'] as IconData;
                }
              });
            },
            selectedColor: AppTheme.primaryGreen,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppTheme.primaryGreen,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? Colors.transparent : AppTheme.border,
              ),
            ),
            showCheckmark: false,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextCapitalization textCapitalization = TextCapitalization.words,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextFormField(
        controller: controller,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.muted,
          ),
          prefixIcon: Icon(prefixIcon, size: 20, color: AppTheme.muted),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
