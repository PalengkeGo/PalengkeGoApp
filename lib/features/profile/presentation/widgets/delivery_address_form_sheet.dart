import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

class AddressSheetSizes {
  static const double min = 0.14;
  static const double initial = 0.45;
  static const double max = 0.62;
  static const List<double> snaps = [min, initial, max];
}

bool isDeliveryAddressValid({
  required String house,
  required String? barangay,
  required String? label,
  required String customLabel,
}) =>
    house.trim().isNotEmpty &&
    (barangay?.trim().isNotEmpty ?? false) &&
    (label?.trim().isNotEmpty ?? false) &&
    (label != 'Custom' || customLabel.trim().isNotEmpty);

class DeliveryAddressFormSheet extends ConsumerStatefulWidget {
  const DeliveryAddressFormSheet({
    super.key,
    required this.scrollController,
    this.sheetController,
    this.selectedLocation,
    this.hasPickedLocation = false,
    this.reverseAddress,
    this.reverseStreetAddress,
    this.reverseBarangay,
    this.onMoveMap,
    this.locationUnavailable = false,
    this.onRetryLocation,
  });

  final ScrollController scrollController;
  final DraggableScrollableController? sheetController;
  final LatLng? selectedLocation;
  final bool hasPickedLocation;
  final String? reverseAddress;
  final String? reverseStreetAddress;
  final String? reverseBarangay;
  final ValueChanged<LatLng>? onMoveMap;
  final bool locationUnavailable;
  final VoidCallback? onRetryLocation;

  @override
  ConsumerState<DeliveryAddressFormSheet> createState() =>
      _DeliveryAddressFormSheetState();
}

class _DeliveryAddressFormSheetState
    extends ConsumerState<DeliveryAddressFormSheet> {
  // Reuse the Naga City barangay values already present in this screen.
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

  static const _savedLabels = ['Home', 'School', 'Work', 'Custom'];
  static const _city = 'Naga City';
  static const _province = 'Camarines Sur';
  static const _postalCode = '4400';

  final _houseController = TextEditingController();
  final _notesController = TextEditingController();
  final _customLabelController = TextEditingController();
  final _houseFocus = FocusNode();
  final _houseKey = GlobalKey();
  Timer? _geocodeDebounce;
  DeliveryAddress? _editingAddress;
  String? _selectedBarangay;
  String? _selectedLabel;
  bool _customLabelSelected = false;
  bool _locationMode = false;
  bool _houseTouched = false;
  bool _barangayTouched = false;
  bool _labelTouched = false;
  bool _customTouched = false;
  bool _geocodeFailed = false;
  bool _saving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is DeliveryAddress) _applyAddress(args);
  }

  @override
  void didUpdateWidget(covariant DeliveryAddressFormSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locationUnavailable && _locationMode) {
      _locationMode = false;
    }
    final positionChanged = widget.reverseAddress != oldWidget.reverseAddress ||
        widget.reverseStreetAddress != oldWidget.reverseStreetAddress ||
        widget.reverseBarangay != oldWidget.reverseBarangay;
    if (!positionChanged) return;
    if (!_locationMode) return;

    final house = widget.reverseStreetAddress?.trim();
    if (house != null && house.isNotEmpty) {
      _houseController.text = house;
    } else {
      final firstPart = widget.reverseAddress?.split(',').first.trim();
      if (firstPart != null && firstPart.isNotEmpty) {
        _houseController.text = firstPart;
      }
    }
    final match = _matchBarangay(widget.reverseBarangay ?? '') ??
        _matchBarangay(widget.reverseAddress ?? '');
    _selectedBarangay = match;
    _geocodeFailed = false;
  }

  static String _normalized(String value) => value
      .toLowerCase()
      .replaceAll('ñ', 'n')
      .replaceAll('sta.', 'santa')
      .trim();

  static String? _matchBarangay(String text) {
    final normalized = _normalized(text);
    for (final barangay in _nagaBarangays) {
      if (normalized.contains(_normalized(barangay))) return barangay;
    }
    return null;
  }

  void _applyAddress(DeliveryAddress address) {
    _editingAddress = address;
    _houseController.text = address.streetAddress;
    _notesController.text = address.notes;
    _selectedBarangay = _matchBarangay(address.fullAddress) ??
        _matchBarangay(address.streetAddress);
    final label = address.label.trim();
    if (_savedLabels.take(3).any((item) => item.toLowerCase() == label.toLowerCase())) {
      _selectedLabel = _savedLabels
          .take(3)
          .firstWhere((item) => item.toLowerCase() == label.toLowerCase());
    } else if (label.isNotEmpty && label.toLowerCase() != 'other') {
      _selectedLabel = 'Custom';
      _customLabelSelected = true;
      _customLabelController.text = label;
    }
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _houseController.dispose();
    _notesController.dispose();
    _customLabelController.dispose();
    _houseFocus.dispose();
    super.dispose();
  }

  bool get _requiredFieldsValid => isDeliveryAddressValid(
    house: _houseController.text,
    barangay: _selectedBarangay,
    label: _selectedLabel,
    customLabel: _customLabelSelected ? _customLabelController.text : 'unused',
  );

  String get _localityAddress =>
      '$_selectedBarangay, $_city, $_province, $_postalCode, Philippines';
  String get _fullAddress => '${_houseController.text.trim()}, $_localityAddress';
  String get _cardAddress => _requiredAddressFieldsValid
      ? _fullAddress
      : (widget.reverseAddress?.trim().isNotEmpty == true
            ? widget.reverseAddress!.trim()
            : 'Location selected. Choose your barangay to complete the address.');
  bool get _showLocationCard =>
      _requiredAddressFieldsValid ||
      (_locationMode && widget.hasPickedLocation && !widget.locationUnavailable);

  void _onAddressChanged() {
    setState(() {
      _geocodeFailed = false;
    });
    _geocodeDebounce?.cancel();
    if (!_requiredAddressFieldsValid) return;
    _geocodeDebounce = Timer(const Duration(milliseconds: 600), _geocodeManualAddress);
  }

  bool get _requiredAddressFieldsValid =>
      _houseController.text.trim().isNotEmpty &&
      (_selectedBarangay?.isNotEmpty ?? false);

  Future<void> _geocodeManualAddress() async {
    final requestAddress = _fullAddress;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'limit': '1',
        'q': requestAddress,
        'countrycodes': 'ph',
      });
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (!mounted || requestAddress != _fullAddress) return;
      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List<dynamic>;
        if (results.isNotEmpty) {
          final result = results.first as Map<String, dynamic>;
          final lat = double.tryParse(result['lat'] as String? ?? '');
          final lon = double.tryParse(result['lon'] as String? ?? '');
          if (lat != null && lon != null) {
            setState(() => _geocodeFailed = false);
            widget.onMoveMap?.call(LatLng(lat, lon));
            return;
          }
        }
      }
      setState(() => _geocodeFailed = true);
    } catch (_) {
      if (mounted && requestAddress == _fullAddress) {
        setState(() => _geocodeFailed = true);
      }
    }
  }

  Map<String, String> get _headers => kIsWeb
      ? const {}
      : const {'User-Agent': 'PalengkeGo/1.0 (contact: palengkego@example.com)'};

  void _selectLocationMode() {
    setState(() {
      _locationMode = true;
      _geocodeFailed = false;
    });
    widget.onRetryLocation?.call();
  }

  void _selectManualMode() => setState(() => _locationMode = false);

  void _focusHouseField() {
    final target = _houseKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 220),
        alignment: 0.15,
      );
    }
    _houseFocus.requestFocus();
  }

  Future<void> _confirm() async {
    setState(() {
      _houseTouched = true;
      _barangayTouched = true;
      _labelTouched = true;
      _customTouched = true;
    });
    if (!_requiredFieldsValid || _saving) return;
    final address = DeliveryAddress(
      addressId: _editingAddress?.addressId,
      label: _customLabelSelected
          ? _customLabelController.text.trim()
          : _selectedLabel!,
      fullAddress: _localityAddress,
      streetAddress: _houseController.text.trim(),
      landmarks: _notesController.text.trim(),
      latitude: widget.hasPickedLocation
          ? widget.selectedLocation?.latitude
          : _editingAddress?.latitude,
      longitude: widget.hasPickedLocation
          ? widget.selectedLocation?.longitude
          : _editingAddress?.longitude,
      isDefault: _editingAddress?.isDefault ?? true,
    );

    final decision = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm delivery address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(address.label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(address.completeAddress),
            if (address.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Note for rider: ${address.notes}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Edit'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (decision != true || !mounted) return;
    await _saveAddress(address);
  }

  Future<void> _saveAddress(DeliveryAddress address) async {
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(preferencesProvider.notifier)
          .saveDeliveryAddress(address);
      if (!mounted) return;
      if (!saved) {
        setState(() => _saving = false);
        AppServices.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: const Text('Could not save address. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _saveAddress(address),
            ),
          ),
        );
        return;
      }
      final normalized = ref.read(preferencesProvider).deliveryAddress ?? address;
      AppServices.scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Delivery address saved.')),
      );
      Navigator.of(context).pop(normalized);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppServices.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Could not save address: $error'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _saveAddress(address),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _buildDragHandle(),
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModePicker(),
                if (widget.locationUnavailable) ...[
                  const SizedBox(height: 12),
                  _buildLocationNotice(),
                ],
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.08),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _showLocationCard
                      ? _buildLocationCard(key: const ValueKey('location'))
                      : const SizedBox.shrink(key: ValueKey('empty-location')),
                ),
                if (_showLocationCard) const SizedBox(height: 16),
                _fieldLabel('House no. / Street / Landmark *'),
                const SizedBox(height: 7),
                KeyedSubtree(
                  key: _houseKey,
                  child: TextField(
                    controller: _houseController,
                    focusNode: _houseFocus,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      _houseTouched = true;
                      _onAddressChanged();
                    },
                    onEditingComplete: () {
                      _houseFocus.unfocus();
                      setState(() => _houseTouched = true);
                    },
                    decoration: _inputDecoration(
                      'e.g. 123 Magsaysay Avenue',
                      prefix: Icons.home_outlined,
                      error: _houseTouched && _houseController.text.trim().isEmpty
                          ? 'Enter your house number, street, or landmark.'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Barangay *'),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBarangay,
                  isExpanded: true,
                  onTap: () => setState(() => _barangayTouched = true),
                  decoration: _inputDecoration('Select barangay', prefix: Icons.location_city_outlined),
                  items: _nagaBarangays
                      .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedBarangay = value;
                      _barangayTouched = true;
                      _geocodeFailed = false;
                    });
                    _onAddressChanged();
                  },
                ),
                if (_barangayTouched && _selectedBarangay == null)
                  _fieldError('Select a barangay.'),
                const SizedBox(height: 14),
                _lockedField('City', _city),
                const SizedBox(height: 10),
                _lockedField('Province', _province),
                const SizedBox(height: 10),
                _lockedField('Postal code', _postalCode),
                const SizedBox(height: 14),
                _fieldLabel('Note for rider (optional)'),
                const SizedBox(height: 7),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    'e.g. Red gate, ring the doorbell. House color, nearby landmark, or other delivery details.',
                    prefix: Icons.notes_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Save as *'),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _savedLabels.map(_labelChip).toList(growable: false),
                ),
                if (_labelTouched && _selectedLabel == null)
                  _fieldError('Choose how to save this address.'),
                if (_customLabelSelected) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customLabelController,
                    maxLength: 20,
                    textCapitalization: TextCapitalization.words,
                    onTap: () => setState(() => _customTouched = true),
                    onChanged: (_) => setState(() => _customTouched = true),
                    decoration: _inputDecoration(
                      'Custom label name',
                      prefix: Icons.edit_location_alt_outlined,
                      error: _customTouched && _customLabelController.text.trim().isEmpty
                          ? 'Enter a label name.'
                          : null,
                    ).copyWith(counterText: ''),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
              onPressed: _requiredFieldsValid && !_saving ? _confirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.35),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirm Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildModePicker() => SegmentedButton<bool>(
    segments: const [
      ButtonSegment(value: false, label: Text('Enter manually')),
      ButtonSegment(value: true, label: Text('Use my location')),
    ],
    selected: {_locationMode},
    onSelectionChanged: (selection) {
      if (selection.first) {
        _selectLocationMode();
      } else {
        _selectManualMode();
      }
    },
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : AppTheme.primaryGreen,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppTheme.primaryGreen : Colors.white,
      ),
    ),
  );

  Widget _buildLocationCard({Key? key}) => Container(
    key: key,
    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
    decoration: BoxDecoration(
      color: AppTheme.primaryGreen.withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.14)),
    ),
    child: Row(
      children: [
        const Icon(Icons.location_on_rounded, color: AppTheme.primaryGreen, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LOCATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Text(_cardAddress, style: const TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              if (_geocodeFailed) ...[
                const SizedBox(height: 4),
                const Text("Couldn't find this exact spot. Move the pin to adjust.", style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'Edit address',
          onPressed: _focusHouseField,
          icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryGreen, size: 19),
        ),
      ],
    ),
  );

  Widget _buildLocationNotice() => Container(
    padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
    decoration: BoxDecoration(
      color: AppTheme.warning.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        const Icon(Icons.location_off_outlined, size: 18, color: AppTheme.warning),
        const SizedBox(width: 8),
        const Expanded(child: Text('Location off. Move the pin or type your address.', style: TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600))),
        TextButton(
          onPressed: _selectLocationMode,
          style: TextButton.styleFrom(foregroundColor: AppTheme.warning, padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  Widget _labelChip(String label) {
    final selected = _selectedLabel == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _selectedLabel = label;
        _customLabelSelected = label == 'Custom';
        _labelTouched = true;
        if (!_customLabelSelected) _customLabelController.clear();
      }),
      avatar: Icon(
        label == 'Home' ? Icons.home_outlined : label == 'School' ? Icons.school_outlined : label == 'Work' ? Icons.work_outline_rounded : Icons.add_rounded,
        size: 17,
        color: selected ? Colors.white : AppTheme.primaryGreen,
      ),
      selectedColor: AppTheme.primaryGreen,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(color: selected ? Colors.white : AppTheme.primaryGreen, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: selected ? Colors.transparent : AppTheme.border)),
      showCheckmark: false,
    );
  }

  Widget _lockedField(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel(label),
      const SizedBox(height: 7),
      TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: _inputDecoration(value, prefix: Icons.lock_outline_rounded).copyWith(
          filled: true,
          fillColor: const Color(0xFFF1F3F2),
          prefixIconColor: AppTheme.muted,
        ),
        enabled: false,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      ),
    ],
  );

  Widget _fieldLabel(String label) => Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary));
  Widget _fieldError(String text) => Padding(padding: const EdgeInsets.only(left: 12, top: 4), child: Text(text, style: const TextStyle(color: AppTheme.error, fontSize: 11)));

  InputDecoration _inputDecoration(String hint, {required IconData prefix, String? error}) => InputDecoration(
    hintText: hint,
    errorText: error,
    prefixIcon: Icon(prefix, size: 19),
    filled: true,
    fillColor: AppTheme.surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5)),
  );

  Widget _buildDragHandle() => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onVerticalDragUpdate: (details) {
      final controller = widget.sheetController;
      if (controller == null || !controller.isAttached) return;
      final height = MediaQuery.sizeOf(context).height;
      if (height > 0) {
        controller.jumpTo((controller.size - details.primaryDelta! / height).clamp(AddressSheetSizes.min, AddressSheetSizes.max));
      }
    },
    onVerticalDragEnd: (details) {
      final controller = widget.sheetController;
      if (controller == null || !controller.isAttached) return;
      final size = controller.size;
      final target = AddressSheetSizes.snaps.reduce((a, b) => (a - size).abs() < (b - size).abs() ? a : b);
      controller.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
    },
    child: SizedBox(
      height: 24,
      width: double.infinity,
      child: Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AppTheme.muted.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)))),
    ),
  );
}
