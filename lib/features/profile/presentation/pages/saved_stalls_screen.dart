import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/features/home/presentation/widgets/stall_card.dart';
import 'package:palengkego/features/profile/application/favorites_provider.dart';
import 'package:palengkego/features/profile/application/blocked_vendors_provider.dart';

class SavedStallsScreen extends ConsumerStatefulWidget {
  const SavedStallsScreen({super.key});

  @override
  ConsumerState<SavedStallsScreen> createState() => _SavedStallsScreenState();
}

class _SavedStallsScreenState extends ConsumerState<SavedStallsScreen> {
  int _selectedIndex = 0; // 0 for Favorites, 1 for Blocked

  @override
  Widget build(BuildContext context) {
    final favoriteVendors = ref.watch(favoriteVendorsProvider);
    final blockedVendors = ref.watch(blockedVendorsListProvider);

    final currentList = _selectedIndex == 0 ? favoriteVendors : blockedVendors;
    final emptyTitle = _selectedIndex == 0
        ? 'No Favorites Yet'
        : 'No Blocked Stalls';
    final emptyMessage = _selectedIndex == 0
        ? 'Stalls you favorite will appear here.'
        : 'Stalls you block will appear here.';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        'assets/icons/back button icon.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          AppTheme.primaryGreen,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Saved Stalls',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),

            // Segmented Pill Control
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 320,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.border, // Lighter slate for track
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Stack(
                  children: [
                    // Highlight pill
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.fastOutSlowIn,
                      left: _selectedIndex == 0 ? 2 : 160,
                      top: 2,
                      bottom: 2,
                      width: 158,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Options
                    Row(
                      children: [
                        _buildTab(0, 'Favorites'),
                        _buildTab(1, 'Blocked'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Grid content
            Expanded(
              child: currentList.when(
                loading: () => const AsyncLoadingView(),
                error: (error, stack) =>
                    AsyncErrorView(message: 'Error: $error'),
                data: (list) {
                  return list.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedIndex == 0
                                    ? Icons.favorite_border_rounded
                                    : Icons.block_flipped,
                                size: 48,
                                color: AppTheme.muted,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                emptyTitle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                emptyMessage,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.55,
                              ),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            if (_selectedIndex == 1) {
                              return _BlockedStallCard(vendor: list[index]);
                            }
                            return StallCard(vendor: list[index]);
                          },
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String title) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? AppTheme.primaryGreen
                  : AppTheme.textSecondary,
            ),
            child: Text(title),
          ),
        ),
      ),
    );
  }
}

/// A card variant for blocked vendors.
/// The Unblock button is overlaid as a strip at the bottom of the card
/// so no extra height is needed — the aspect ratio stays identical to
/// the Favorites tab and there is zero overflow risk.
class _BlockedStallCard extends ConsumerWidget {
  final dynamic vendor;

  const _BlockedStallCard({required this.vendor});

  void _unblock(BuildContext context, WidgetRef ref) {
    final vendorId = vendor.id;
    final vendorName = vendor.name;

    ref.read(blockedVendorsProvider.notifier).unblock(vendorId);
    AppServices.showSnackBar('$vendorName has been unblocked.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // The regular stall card — unchanged layout, no height modification
        StallCard(vendor: vendor),

        // Subtle dim overlay so the card looks "blocked"
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(color: Colors.black.withValues(alpha: 0.08)),
          ),
        ),

        // Red unblock strip pinned to the bottom of the card
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () => _unblock(context, ref),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: Container(
                height: 34,
                color: const Color(0xFFDC2626),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_open_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Unblock',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
