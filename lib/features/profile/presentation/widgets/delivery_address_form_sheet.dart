import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

/// Snap sizes of the address bottom sheet (fraction of screen height).
/// The max size is kept low enough that the map pin stays visible above it.
class AddressSheetSizes {
  static const double min = 0.14;
  static const double initial = 0.45;
  static const double max = 0.62;
  static const List<double> snaps = [min, initial, max];
}

/// Scrollable address form inside the "Set Delivery Address" map screen.
/// Owns the field controllers and pre-fills them from the saved address
/// or the route arguments (DeliveryAddress). Pops the route with the
/// built [DeliveryAddress] on confirm.
class DeliveryAddressFormSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final LatLng? selectedLocation;
  final String? reverseAddress;
  final String? reverseStreetAddress;
  final String? reverseBarangay;
  final ValueChanged<LatLng>? onMoveMap;
  final DraggableScrollableController? sheetController;
  final bool locationUnavailable;
  final VoidCallback? onRetryLocation;

  const DeliveryAddressFormSheet({
    super.key,
    required this.scrollController,
    this.sheetController,
    this.selectedLocation,
    this.reverseAddress,
    this.reverseStreetAddress,
    this.reverseBarangay,
    this.onMoveMap,
    this.locationUnavailable = false,
    this.onRetryLocation,
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
  final _primaryFocus = FocusNode();

  IconData? _selectedCustomIcon;
  DeliveryAddress? _editingAddress;

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

  static const _predefinedLabelNames = ['home', 'work', 'school'];

  static IconData _iconForCodePoint(int codePoint) {
    for (final icon in _addressIconList) {
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.favorite_rounded;
  }

  /// All 27 barangays of Naga City.
  static const List<String> _nagaBarangays = [
    'Abella',
    'Bagumbayan Norte',
    'Bagumbayan Sur',
    'Balatas',
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

  static const List<String> _nagaLandmarks = [
    'SM City Naga',
    "Naga City People's Mall - Abella",
    'Ateneo de Naga University',
    'Universidad de Sta. Isabel',
    'Naga City Hall',
    'Bicol Medical Center',
    'Naga Metropolitan Cathedral',
    'Robinsons Naga',
    'Magsaysay Avenue - Naga',
    'Concepcion Grande - Naga City',
    'STI College Naga',
    'Landers Superstore Naga',
    'Sogo Hotel Naga',
    'LCC Mall Naga',
    'Grandmaster Mall Naga',
    'Master Square Naga - Penafrancia Ave',
    'Puregold Naga',
    'S&R Membership Shopping Naga',
    'Bicol Central Academy',
    'Naga City Science High School',
    'JMR Coliseum',
    'E-Mall Naga',
  ];

  String? _selectedBarangay;

  /// Set when the user picks a barangay manually; the next reverse-geocode
  /// result (caused by the map moving to that barangay) must not override it.
  bool _keepBarangayOnce = false;

  /// Whether the inline "Custom label" field is open.
  bool _showCustomField = false;

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ñ', 'n')
      .replaceAll('sta.', 'santa')
      .trim();

  /// Finds the Naga barangay mentioned in [text], or null.
  static String? _matchBarangay(String text) {
    final t = _norm(text);
    if (t.isEmpty) return null;
    for (final b in _nagaBarangays) {
      if (t.contains(_norm(b))) return b;
    }
    return null;
  }

  static const Map<String, LatLng> _landmarkCoords = {
    'SM City Naga': LatLng(13.6195, 123.1838),
    "Naga City People's Mall - Abella": LatLng(13.6218, 123.1817),
    'Ateneo de Naga University': LatLng(13.6201, 123.1872),
    'Universidad de Sta. Isabel': LatLng(13.6189, 123.1865),
    'Naga City Hall': LatLng(13.6211, 123.1892),
    'Bicol Medical Center': LatLng(13.6192, 123.1765),
    'Naga Metropolitan Cathedral': LatLng(13.6197, 123.1811),
    'Robinsons Naga': LatLng(13.6175, 123.1912),
    'Magsaysay Avenue - Naga': LatLng(13.6185, 123.1855),
    'STI College Naga': LatLng(13.6215, 123.1902),
    'Landers Superstore Naga': LatLng(13.6252, 123.1841),
    'Sogo Hotel Naga': LatLng(13.6203, 123.1844),
    'LCC Mall Naga': LatLng(13.6188, 123.1881),
    'Grandmaster Mall Naga': LatLng(13.6221, 123.1822),
    'Master Square Naga - Penafrancia Ave': LatLng(13.6205, 123.1833),
    'Puregold Naga': LatLng(13.6182, 123.1805),
    'S&R Membership Shopping Naga': LatLng(13.6255, 123.1845),
  };

  List<Map<String, dynamic>> _landmarkResults = [];
  Timer? _searchDebounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    final currentAddress = ref.read(preferencesProvider).deliveryAddress;
    if (currentAddress != null) {
      _applyAddress(currentAddress);
    }
    if (widget.reverseAddress != null && widget.reverseAddress!.isNotEmpty) {
      _primaryAddressController.text = widget.reverseAddress!;
    }
  }

  @override
  void didUpdateWidget(covariant DeliveryAddressFormSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reverseAddress != null &&
        (widget.reverseAddress != oldWidget.reverseAddress ||
            widget.reverseStreetAddress != oldWidget.reverseStreetAddress ||
            widget.reverseBarangay != oldWidget.reverseBarangay) &&
        widget.reverseAddress!.isNotEmpty) {
      // Sync pin tip → fields for preview only (do NOT save to preferences yet)
      // Save happens only on Confirm, so checkout stays on the last confirmed saved address
      _primaryAddressController.text = widget.reverseAddress!;
      final street = widget.reverseStreetAddress?.trim() ?? '';
      if (street.isNotEmpty) {
        _streetAddressController.text = street;
      }
      if (_keepBarangayOnce) {
        // The map moved because the user picked a barangay — keep their choice.
        _keepBarangayOnce = false;
      } else {
        // Prefer the geocoder's barangay field, then fall back to the full
        // address. Clear the selection when the pin is outside any known
        // barangay so a stale value (e.g. "Tabuco" for an Abella pin) never stays.
        _selectedBarangay = _matchBarangay(widget.reverseBarangay ?? '') ??
            _matchBarangay(widget.reverseAddress!);
      }
    }
  }

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is DeliveryAddress) {
        _applyAddress(args);
      }
    }
  }

  void _applyAddress(DeliveryAddress address) {
    _editingAddress = address;
    _labelController.text = address.label == 'other' ? '' : address.label;
    _primaryAddressController.text = address.primaryAddress;
    _streetAddressController.text = address.streetAddress;
    _notesController.text = address.notes;
    if (address.iconCodePoint != null) {
      _selectedCustomIcon = _iconForCodePoint(address.iconCodePoint!);
    }
    if (address.primaryAddress.isNotEmpty) {
      // Try to detect barangay from existing address for the dropdown
      _selectedBarangay = _matchBarangay(address.streetAddress) ??
          _matchBarangay(address.primaryAddress) ??
          _selectedBarangay;
    }
  }

  Future<void> _searchLandmarks(String query) async {
    if (query.trim().length < 3) {
      if (mounted) setState(() => _landmarkResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&limit=5&q=${Uri.encodeComponent('$query, Naga City, Camarines Sur')}&viewbox=123.12,13.69,123.28,13.55&bounded=1&addressdetails=1',
      );
      final resp = await http.get(
        uri,
        headers: kIsWeb ? {} : {'User-Agent': 'PalengkeGo/1.0 (contact: palengkego@example.com)'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        if (mounted) setState(() => _landmarkResults = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _labelController.dispose();
    _primaryAddressController.dispose();
    _streetAddressController.dispose();
    _notesController.dispose();
    _primaryFocus.dispose();
    super.dispose();
  }

  void _animateSheetTo(double target) {
    final ctrl = widget.sheetController;
    if (ctrl == null || !ctrl.isAttached) return;
    ctrl.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDragHandle(),
        // Scrollable form fields
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            child: SingleChildScrollView(
              controller: widget.scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.locationUnavailable) ...[
                    _buildLocationNotice(),
                    const SizedBox(height: 10),
                  ],

                  _buildPinCard(),

                  // Naga City Barangay Autocomplete List
                  if (_primaryAddressController.text.isNotEmpty)
                    _buildBarangaySuggestions(_primaryAddressController),

                  const SizedBox(height: 18),

                  // Label (Home, Work, School, + Custom)
                  _buildInputLabel('Save as'),
                  const SizedBox(height: 8),
                  _buildLabelChips(),
                  if (_showCustomField) ...[
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _labelController,
                      hintText: 'Custom label (e.g. Lola\'s house)',
                      prefixIcon: _selectedCustomIcon ?? Icons.add_reaction_outlined,
                      onPrefixTap: () => _showIconPicker(context),
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Barangay Dropdown (Naga City only)
                  _buildInputLabel('Barangay *'),
                  const SizedBox(height: 8),
                  Container(
                    height: 52,
                    decoration: _fieldDecoration(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBarangay,
                        hint: const Text('Select barangay', style: TextStyle(color: AppTheme.muted, fontSize: 14)),
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(14),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.muted),
                        items: _nagaBarangays.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B))))).toList(),
                        onChanged: (val) async {
                          if (val == null) return;
                          setState(() => _selectedBarangay = val);
                          // Move map to selected barangay
                          await _searchLandmarks('$val, Naga City');
                          if (_landmarkResults.isNotEmpty && widget.onMoveMap != null) {
                            final first = _landmarkResults.first;
                            final lat = double.tryParse(first['lat'] as String? ?? '');
                            final lon = double.tryParse(first['lon'] as String? ?? '');
                            if (lat != null && lon != null) {
                              _keepBarangayOnce = true;
                              widget.onMoveMap!(LatLng(lat, lon));
                            }
                          } else if (_landmarkCoords.containsKey(val)) {
                            _keepBarangayOnce = true;
                            widget.onMoveMap?.call(_landmarkCoords[val]!);
                          }
                          if (mounted) setState(() => _landmarkResults = []);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Street / House No. / Landmark
                  _buildInputLabel('House no. / Street / Landmark *'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _streetAddressController,
                    hintText: 'e.g. 123 Magsaysay Ave',
                    prefixIcon: Icons.location_on_outlined,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (val) => setState(() {}),
                  ),

                  const SizedBox(height: 16),

                  // Notes Input
                  _buildInputLabel('Note for rider (optional)'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _notesController,
                    hintText: 'e.g. Red gate, ring the doorbell',
                    prefixIcon: Icons.notes_outlined,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Sticky Confirm Button — always visible at the bottom of the sheet
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _confirm,
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
          ),
        ),
      ],
    );
  }

  void _confirm() {
    if (_selectedBarangay == null || _selectedBarangay!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a barangay')),
      );
      return;
    }
    if (_streetAddressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter house no. / street')),
      );
      return;
    }
    final streetWithBrgy = '${_streetAddressController.text}, $_selectedBarangay, Naga City';
    final resolvedLabel = _labelController.text.trim().isEmpty
        ? (_editingAddress?.label.isNotEmpty == true
            ? _editingAddress!.label
            : 'Home')
        : _labelController.text.trim();
    Navigator.pop(
      context,
      DeliveryAddress(
        addressId: _editingAddress?.addressId,
        isDefault: _editingAddress?.isDefault ?? false,
        label: resolvedLabel,
        primaryAddress: _primaryAddressController.text.trim(),
        streetAddress: streetWithBrgy,
        notes: _notesController.text.trim(),
        latitude: widget.selectedLocation?.latitude ??
            _editingAddress?.latitude,
        longitude: widget.selectedLocation?.longitude ??
            _editingAddress?.longitude,
        iconCodePoint:
            (_selectedCustomIcon ?? Icons.favorite_rounded)
                .codePoint,
      ),
    );
  }

  // Interactive Drag Handle Pill
  Widget _buildDragHandle() {
    const sizes = AddressSheetSizes.snaps;
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final ctrl = widget.sheetController;
          if (ctrl == null || !ctrl.isAttached) return;
          final current = ctrl.size;
          _animateSheetTo(current <= (sizes[0] + sizes[1]) / 2
              ? sizes[1]
              : (current <= (sizes[1] + sizes[2]) / 2 ? sizes[2] : sizes[0]));
        },
        onVerticalDragUpdate: (details) {
          final ctrl = widget.sheetController;
          if (ctrl != null && ctrl.isAttached) {
            final screenH = MediaQuery.sizeOf(context).height;
            if (screenH > 0) {
              final delta = -details.primaryDelta! / screenH;
              ctrl.jumpTo((ctrl.size + delta)
                  .clamp(AddressSheetSizes.min, AddressSheetSizes.max));
            }
          }
        },
        onVerticalDragEnd: (details) {
          final ctrl = widget.sheetController;
          if (ctrl == null || !ctrl.isAttached) return;
          final current = ctrl.size;
          final velocity = details.primaryVelocity ?? 0;
          double target;
          if (velocity < -300) {
            target = current < sizes[1] ? sizes[1] : sizes[2];
          } else if (velocity > 300) {
            target = current > sizes[1] ? sizes[1] : sizes[0];
          } else {
            target = sizes.reduce((a, b) =>
                (a - current).abs() < (b - current).abs() ? a : b);
          }
          _animateSheetTo(target);
        },
        child: SizedBox(
          width: double.infinity,
          height: 24,
          child: Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.muted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Slim inline notice shown when GPS is unavailable
  Widget _buildLocationNotice() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_outlined, size: 18, color: AppTheme.warning),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Location off. Move the pin or type your address.',
              style: TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600),
            ),
          ),
          if (widget.onRetryLocation != null)
            TextButton(
              onPressed: widget.onRetryLocation,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.warning,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  // Pin dropped near info — editable search field, wraps to 2 lines
  Widget _buildPinCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.near_me,
              size: 20,
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
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: _primaryAddressController,
                  focusNode: _primaryFocus,
                  minLines: 1,
                  maxLines: 2,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    hintText: 'Search area or landmark',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.muted,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  onTap: () => setState(() {}),
                  onChanged: (val) {
                    setState(() {});
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 500), () => _searchLandmarks(val));
                  },
                  onSubmitted: (val) async {
                    await _searchLandmarks(val);
                    if (_landmarkResults.isNotEmpty && widget.onMoveMap != null) {
                      final first = _landmarkResults.first;
                      final lat = double.tryParse(first['lat'] as String? ?? '');
                      final lon = double.tryParse(first['lon'] as String? ?? '');
                      if (lat != null && lon != null) {
                        widget.onMoveMap!(LatLng(lat, lon));
                        setState(() => _landmarkResults = []);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Search address',
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryGreen),
            onPressed: () {
              _primaryFocus.requestFocus();
              _primaryAddressController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _primaryAddressController.text.length,
              );
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  void _showIconPicker(BuildContext context) {
    final icons = [
      Icons.home_outlined,
      Icons.work_outline_rounded,
      Icons.school_outlined,
      Icons.favorite_outline_rounded,
      Icons.lock_outline_rounded,
      Icons.star_outline_rounded,
      Icons.fitness_center_rounded,
      Icons.local_cafe_outlined,
    ];
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
    final query = controller.text.toLowerCase().trim();
    final barangayMatches = _nagaBarangays
        .where((b) => b.toLowerCase().contains(query))
        .take(3)
        .toList();
    final landmarkMatches = _nagaLandmarks
        .where((l) => l.toLowerCase().contains(query))
        .take(3)
        .toList();

    final hasLocal = barangayMatches.isNotEmpty || landmarkMatches.isNotEmpty;
    final hasRemote = _landmarkResults.isNotEmpty;

    if (!hasLocal && !hasRemote && query.isEmpty) return const SizedBox.shrink();
    if (!hasLocal && !hasRemote) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...barangayMatches.map((barangay) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.location_city_rounded, size: 18, color: AppTheme.primaryGreen),
                title: Text('$barangay, Naga City', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                onTap: () async {
                  setState(() {
                    controller.text = '$barangay, Naga City';
                    controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                    _selectedBarangay = barangay;
                    _landmarkResults = [];
                  });
                  _primaryFocus.unfocus();
                  await _searchLandmarks('$barangay, Naga City');
                  if (_landmarkResults.isNotEmpty && widget.onMoveMap != null) {
                    final first = _landmarkResults.first;
                    final lat = double.tryParse(first['lat'] as String? ?? '');
                    final lon = double.tryParse(first['lon'] as String? ?? '');
                    if (lat != null && lon != null) {
                      _keepBarangayOnce = true;
                      widget.onMoveMap!(LatLng(lat, lon));
                    }
                  }
                  if (mounted) setState(() => _landmarkResults = []);
                },
              );
            }),
            ...landmarkMatches.map((lm) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.place_rounded, size: 18, color: AppTheme.primaryGreen),
                title: Text(lm, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                subtitle: const Text('Tap to pin location', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                onTap: () {
                  _primaryFocus.unfocus();
                  if (_landmarkCoords.containsKey(lm) && widget.onMoveMap != null) {
                    widget.onMoveMap!(_landmarkCoords[lm]!);
                    setState(() {
                      controller.text = lm;
                      controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                      _landmarkResults = [];
                    });
                    return;
                  }
                  setState(() {
                    controller.text = lm;
                    controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                    _landmarkResults = [];
                  });
                  _searchLandmarks(lm);
                },
              );
            }),
            ..._landmarkResults.map((place) {
              final name = place['display_name'] as String? ?? '';
              final short = name.split(',').take(3).join(',');
              return ListTile(
                dense: true,
                leading: _isSearching
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search_rounded, size: 18, color: AppTheme.primaryGreen),
                title: Text(short, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  final lat = double.tryParse(place['lat'] as String? ?? '');
                  final lon = double.tryParse(place['lon'] as String? ?? '');
                  if (lat != null && lon != null && widget.onMoveMap != null) {
                    _primaryFocus.unfocus();
                    widget.onMoveMap!(LatLng(lat, lon));
                    setState(() {
                      controller.text = short;
                      _landmarkResults = [];
                    });
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelChips() {
    final predefinedLabels = <Map<String, dynamic>>[
      {'name': 'Home', 'icon': Icons.home_outlined},
      {'name': 'Work', 'icon': Icons.work_outline},
      {'name': 'School', 'icon': Icons.school_outlined},
    ];

    // While the custom field is open, don't echo the typed text as a chip.
    final currentText = _labelController.text.trim();
    if (currentText.isNotEmpty && !_showCustomField) {
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
              'icon': addr.iconCodePoint != null
                  ? _iconForCodePoint(addr.iconCodePoint!)
                  : Icons.favorite_border_rounded,
            });
          }
        }
      }
    } catch (_) {}

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...predefinedLabels.map((label) {
            final isSelected = !_showCustomField &&
                _labelController.text.toLowerCase().trim() ==
                    (label['name'] as String).toLowerCase().trim();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _labelChip(
                text: label['name'] as String,
                icon: label['icon'] as IconData,
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _showCustomField = false;
                    _labelController.text = selected
                        ? label['name'] as String
                        : '';
                    if (selected &&
                        !_predefinedLabelNames
                            .contains((label['name'] as String).toLowerCase())) {
                      _selectedCustomIcon = label['icon'] as IconData;
                    }
                  });
                },
              ),
            );
          }),
          // "+ Custom" chip opens the inline custom label field
          _labelChip(
            text: 'Custom',
            icon: Icons.add_rounded,
            selected: _showCustomField,
            onSelected: (selected) {
              setState(() {
                _showCustomField = selected;
                final isPredefined = _predefinedLabelNames
                    .contains(_labelController.text.trim().toLowerCase());
                if (selected && isPredefined) _labelController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _labelChip({
    required String text,
    required IconData icon,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return ChoiceChip(
      label: Text(text),
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : AppTheme.primaryGreen,
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppTheme.primaryGreen,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.primaryGreen,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? Colors.transparent : AppTheme.border,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  BoxDecoration _fieldDecoration() => BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    VoidCallback? onPrefixTap,
    TextCapitalization textCapitalization = TextCapitalization.words,
    ValueChanged<String>? onChanged,
  }) {
    final iconWidget = Icon(
      prefixIcon,
      size: 20,
      color: onPrefixTap != null ? AppTheme.primaryGreen : AppTheme.muted,
    );
    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintMaxLines: 1,
        hintStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppTheme.muted,
        ),
        prefixIcon: onPrefixTap != null
            ? IconButton(
                icon: iconWidget,
                tooltip: 'Choose icon',
                onPressed: onPrefixTap,
              )
            : iconWidget,
        filled: true,
        fillColor: AppTheme.surface,
        isDense: true,
        constraints: const BoxConstraints(minHeight: 52),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
        ),
      ),
    );
  }
}
