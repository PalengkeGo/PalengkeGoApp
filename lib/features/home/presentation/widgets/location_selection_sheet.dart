import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

class LocationSelectionSheet extends ConsumerStatefulWidget {
  const LocationSelectionSheet({super.key});

  @override
  ConsumerState<LocationSelectionSheet> createState() =>
      _LocationSelectionSheetState();
}

class _LocationSelectionSheetState
    extends ConsumerState<LocationSelectionSheet> {
  DeliveryAddress? _selectedAddress;

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

  @override
  void initState() {
    super.initState();
    _selectedAddress = ref.read(preferencesProvider).deliveryAddress;
  }

  Future<void> _handleUseCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is permanently denied. Please enable it in Settings.',
              ),
            ),
          );
        }
        return;
      }

      // This call natively triggers Android's Google Location Accuracy prompt
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        const currentAddr = DeliveryAddress(
          primaryAddress: 'Triangulo, Naga City',
          streetAddress: 'Current GPS Location',
          label: 'Home',
        );
        ref.read(preferencesProvider.notifier).selectAddress(currentAddr);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated to current location'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Location services are disabled. Please enable them.',
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                Geolocator.openLocationSettings();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  IconData _getIconForAddress(DeliveryAddress address) {
    if (address.iconCodePoint != null) {
      return _iconForCodePoint(address.iconCodePoint!);
    }
    final lower = address.label.toLowerCase().trim();
    if (lower == 'home') return Icons.home_rounded;
    if (lower == 'work') return Icons.work_rounded;
    if (lower == 'school') return Icons.school_rounded;
    return Icons.favorite_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final prefsState = ref.watch(preferencesProvider);
    final savedAddresses = prefsState.savedAddresses;

    return Container(
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Where to?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
                    letterSpacing: -0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.public,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'PH',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            InkWell(
              onTap: _handleUseCurrentLocation,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.near_me_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use current location',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Enable location services',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),
            const Text(
              'SAVED ADDRESSES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.muted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            // Saved locations list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: savedAddresses.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final address = savedAddresses[index];
                  final isSelected = _selectedAddress?.label == address.label;
                  final icon = _getIconForAddress(address);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAddress = address;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutQuint,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.scaffoldBackground
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : AppTheme.border,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryGreen.withValues(
                                    alpha: 0.08,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.surfaceContainerLow,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  address.label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${address.streetAddress}, ${address.primaryAddress}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? AppTheme.primaryGreen.withValues(
                                            alpha: 0.7,
                                          )
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit address',
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () async {
                              final result = await Navigator.of(context)
                                  .pushNamed(
                                    AppRoutes.setDeliveryAddress,
                                    arguments: address,
                                  );
                              if (result is DeliveryAddress &&
                                  context.mounted) {
                                ref
                                    .read(preferencesProvider.notifier)
                                    .saveDeliveryAddress(result);
                                setState(() {
                                  _selectedAddress = result;
                                });
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Remove address',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: Color(0xFFEF4444),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Text(
                                    'Delete Address',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                  content: Text(
                                    'Are you sure you want to remove "${address.label}" from your saved addresses?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx, false),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(color: AppTheme.textSecondary),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEF4444),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(dialogCtx, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && context.mounted) {
                                ref
                                    .read(preferencesProvider.notifier)
                                    .removeDeliveryAddress(address);
                                setState(() {
                                  _selectedAddress = ref
                                      .read(preferencesProvider)
                                      .deliveryAddress;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${address.label} address removed'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primaryGreen,
                              size: 24,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Add new address button
            InkWell(
              onTap: () async {
                final result = await Navigator.of(
                  context,
                ).pushNamed(AppRoutes.setDeliveryAddress);
                if (result is DeliveryAddress) {
                  ref
                      .read(preferencesProvider.notifier)
                      .saveDeliveryAddress(result);
                  setState(() {
                    _selectedAddress = ref
                        .read(preferencesProvider)
                        .deliveryAddress;
                  });
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.border,
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_location_alt_rounded,
                      color: AppTheme.accentGreen,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Add new address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedAddress == null
                    ? null
                    : () {
                        ref
                            .read(preferencesProvider.notifier)
                            .selectAddress(_selectedAddress!);
                        Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.primaryGreen.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Confirm Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
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
