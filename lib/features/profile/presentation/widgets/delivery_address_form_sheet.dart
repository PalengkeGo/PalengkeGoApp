import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

/// Scrollable address form inside the "Set Delivery Address" map screen.
/// Owns the field controllers and pre-fills them from the saved address
/// or the route arguments (DeliveryAddress). Pops the route with the
/// built [DeliveryAddress] on confirm.
class DeliveryAddressFormSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const DeliveryAddressFormSheet({super.key, required this.scrollController});

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

  @override
  void initState() {
    super.initState();
    final currentAddress = ref.read(preferencesProvider).deliveryAddress;
    _applyAddress(currentAddress);
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
    _primaryAddressController.text = address.primaryAddress.isEmpty
        ? 'Magsaysay Ave, Naga City'
        : address.primaryAddress;
    _streetAddressController.text = address.streetAddress;
    _notesController.text = address.notes;
    if (address.iconCodePoint != null) {
      _selectedCustomIcon = _iconForCodePoint(address.iconCodePoint!);
    }
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
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: 'Enter City/Area',
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

          // Street Address Input
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
    final matches = _nagaBarangays
        .where((b) => b.toLowerCase().contains(query))
        .take(5)
        .toList();

    if (matches.isEmpty) return const SizedBox.shrink();

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
        children: matches.map((barangay) {
          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.location_city_rounded,
              size: 18,
              color: AppTheme.primaryGreen,
            ),
            title: Text(
              '$barangay, Naga City',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            onTap: () {
              setState(() {
                controller.text = '$barangay, Naga City';
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length),
                );
              });
            },
          );
        }).toList(),
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
