import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

/// Scrollable address form inside the "Set Delivery Address" map screen.
/// Owns the field controllers and pre-fills them from the saved address
/// or the route arguments (DeliveryAddress). Pops the route with the
/// built [DeliveryAddress] on confirm.
class DeliveryAddressFormSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final LatLng? selectedLocation;
  final String? reverseAddress;
  final ValueChanged<LatLng>? onMoveMap;

  const DeliveryAddressFormSheet({
    super.key,
    required this.scrollController,
    this.selectedLocation,
    this.reverseAddress,
    this.onMoveMap,
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
    _applyAddress(currentAddress);
    if (widget.reverseAddress != null && widget.reverseAddress!.isNotEmpty) {
      _primaryAddressController.text = widget.reverseAddress!;
    }
  }

  @override
  void didUpdateWidget(covariant DeliveryAddressFormSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reverseAddress != null &&
        widget.reverseAddress != oldWidget.reverseAddress &&
        widget.reverseAddress!.isNotEmpty) {
      // Sync pin tip → fields for preview only (do NOT save to preferences yet)
      // Save happens only on Confirm, so checkout stays on the last confirmed saved address
      _primaryAddressController.text = widget.reverseAddress!;
      final parts = widget.reverseAddress!.split(',').map((e) => e.trim()).toList();
      final streetPart = parts.isNotEmpty ? parts.first : '';
      final barangayPart = parts.length > 1 ? parts[1] : '';
      if (streetPart.isNotEmpty) {
        _streetAddressController.text = streetPart;
      }
      if (barangayPart.isNotEmpty) {
        for (final b in _nagaBarangays) {
          if (barangayPart.toLowerCase().contains(b.toLowerCase()) ||
              b.toLowerCase().contains(barangayPart.toLowerCase())) {
            setState(() => _selectedBarangay = b);
            break;
          }
        }
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
    _labelController.text = address.label == 'other' ? '' : address.label;
    _primaryAddressController.text = address.primaryAddress;
    _streetAddressController.text = address.streetAddress;
    _notesController.text = address.notes;
    if (address.iconCodePoint != null) {
      _selectedCustomIcon = _iconForCodePoint(address.iconCodePoint!);
    }
    if (address.primaryAddress.isNotEmpty) {
      // Try to detect barangay from existing address for the dropdown
      for (final b in _nagaBarangays) {
        if (address.primaryAddress.toLowerCase().contains(b.toLowerCase()) ||
            address.streetAddress.toLowerCase().contains(b.toLowerCase())) {
          _selectedBarangay = b;
          break;
        }
      }
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
      final resp = await http.get(uri, headers: {'User-Agent': 'PalengkeGo/1.0'});
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
          // Drag Handle Pill
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

          // Pin dropped near info
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
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: 'Enter City/Area or landmark',
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
              ],
            ),
          ),

          // Naga City Barangay Autocomplete List
          if (_primaryAddressController.text.isNotEmpty)
            _buildBarangaySuggestions(_primaryAddressController),

          const SizedBox(height: 20),

          // Label Input (Home, Work, etc)
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

          // Barangay Dropdown (Naga City only)
          _buildInputLabel('BARANGAY *'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBarangay,
                hint: const Text('Select Barangay', style: TextStyle(color: AppTheme.muted, fontSize: 14)),
                isExpanded: true,
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
                    if (lat != null && lon != null) widget.onMoveMap!(LatLng(lat, lon));
                  } else if (_landmarkCoords.containsKey(val)) {
                    widget.onMoveMap?.call(_landmarkCoords[val]!);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Street / House No. / Landmark
          _buildInputLabel('HOUSE NO. / STREET / LANDMARK *'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _streetAddressController,
            hintText: 'House No., Street Name, Landmark (e.g. 123 Magsaysay Ave, near SM)',
            prefixIcon: Icons.location_on_outlined,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (val) => setState(() {}),
          ),
          if (_streetAddressController.text.isNotEmpty)
            _buildBarangaySuggestions(_streetAddressController),

          const SizedBox(height: 16),

          // Notes Input
          _buildInputLabel('ADD NOTES FOR COURIER (OPTIONAL)'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _notesController,
            hintText: 'e.g. Red gate, ring the doorbell',
            prefixIcon: Icons.notes_outlined,
            textCapitalization: TextCapitalization.sentences,
          ),

          const SizedBox(height: 24),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                final streetWithBrgy = _selectedBarangay != null && _selectedBarangay!.isNotEmpty
                    ? '${_streetAddressController.text}, $_selectedBarangay, Naga City'
                    : _streetAddressController.text;
                Navigator.pop(
                  context,
                  DeliveryAddress(
                    label: _labelController.text.isEmpty
                        ? 'Home'
                        : _labelController.text,
                    primaryAddress: _primaryAddressController.text,
                    streetAddress: streetWithBrgy,
                    notes: _notesController.text,
                    latitude: widget.selectedLocation?.latitude,
                    longitude: widget.selectedLocation?.longitude,
                    iconCodePoint:
                        (_selectedCustomIcon ?? Icons.favorite_rounded)
                            .codePoint,
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
                await _searchLandmarks('$barangay, Naga City');
                if (_landmarkResults.isNotEmpty && widget.onMoveMap != null) {
                  final first = _landmarkResults.first;
                  final lat = double.tryParse(first['lat'] as String? ?? '');
                  final lon = double.tryParse(first['lon'] as String? ?? '');
                  if (lat != null && lon != null) widget.onMoveMap!(LatLng(lat, lon));
                }
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
                // Immediate move using known coordinates if available
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
        children: predefinedLabels.map((label) {
          final isSelected =
              _labelController.text.toLowerCase().trim() ==
              (label['name'] as String).toLowerCase().trim();
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label['name'] as String),
              avatar: Icon(
                label['icon'] as IconData,
                size: 16,
                color: isSelected ? Colors.white : AppTheme.primaryGreen,
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _labelController.text = selected
                      ? label['name'] as String
                      : '';
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
      ),
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
