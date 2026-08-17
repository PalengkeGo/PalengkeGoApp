import 'package:palengkego/core/theme/app_theme.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/profile/presentation/widgets/delivery_address_form_sheet.dart';
import 'package:palengkego/features/profile/presentation/widgets/delivery_address_map_background.dart';

class SetDeliveryAddressScreen extends ConsumerStatefulWidget {
  const SetDeliveryAddressScreen({super.key});

  @override
  ConsumerState<SetDeliveryAddressScreen> createState() =>
      _SetDeliveryAddressScreenState();
}

class _SetDeliveryAddressScreenState
    extends ConsumerState<SetDeliveryAddressScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          const bottomSheetHeight = 420.0; // Approximate height of bottom sheet
          const headerHeight = 60.0; // SafeArea + padding
          const visibleMapTop = headerHeight;
          final visibleMapBottom = constraints.maxHeight - bottomSheetHeight;
          final visibleMapCenter = (visibleMapTop + visibleMapBottom) / 2;
          final pinTopPosition =
              visibleMapCenter - 40; // Offset up by half the pin height

          return Stack(
            children: [
              // Map Background (placeholder with grid pattern)
              DeliveryAddressMapBackground(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),

              // Center Pin - dynamically positioned above the bottom sheet
              Positioned(
                top: pinTopPosition,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tooltip above the pin
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
                        'Move pin to adjust',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Pin icon with animation effect
                    const Icon(
                      Icons.location_on,
                      size: 48,
                      color: AppTheme.primaryGreen,
                    ),
                    // Pin shadow
                    Container(
                      width: 20,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
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
