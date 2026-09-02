import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:palengkego/core/config/categories.dart';
import 'package:palengkego/core/widgets/animated_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/home/application/search_provider.dart';
import 'package:palengkego/features/home/presentation/widgets/stall_card.dart';
import 'package:palengkego/features/home/presentation/widgets/market_empty_state.dart';

/// Stall browser shown when no search query is active:
/// category chips + optional Meat subcategory row + stall grid.
class MarketStallBrowser extends ConsumerStatefulWidget {
  const MarketStallBrowser({super.key});

  @override
  ConsumerState<MarketStallBrowser> createState() => _MarketStallBrowserState();
}

class _MarketStallBrowserState extends ConsumerState<MarketStallBrowser> {
  static final _categories = <String>['All', ...AppCategories.all];

  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final filteredVendorsAsync = ref.watch(
      filteredVendorsProvider(_selectedCategory),
    );

    return Column(
      children: [
        // Category chips
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                return MarketCategoryChip(
                  label: category,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() => _selectedCategory = category);
                    ref
                        .read(selectedSubcategoryProvider.notifier)
                        .setSubcategory('All');
                  },
                );
              },
            ),
          ),
        ),
        // Subcategory chips (Animated drop-down)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuart,
          child: _selectedCategory == 'Meat'
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final subcats = ['All', 'Beef', 'Pork'];
                        final subcat = subcats[index];
                        final selectedSub = ref.watch(
                          selectedSubcategoryProvider,
                        );
                        return MarketSubcategoryChip(
                          label: subcat,
                          isSelected: selectedSub == subcat,
                          onTap: () => ref
                              .read(selectedSubcategoryProvider.notifier)
                              .setSubcategory(subcat),
                        );
                      },
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: filteredVendorsAsync.when(
            loading: () => const AsyncLoadingView(),
            error: (err, _) => AsyncErrorView(message: 'Error: $err'),
            data: (filteredVendors) {
              if (filteredVendors.isEmpty) {
                return const MarketEmptyState(query: '');
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Stalls',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.border,
                            ),
                          ),
                          child: Text(
                            '${filteredVendors.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredVendors.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 18,
                            childAspectRatio: 0.55,
                          ),
                      itemBuilder: (context, index) {
                        final vendor = filteredVendors[index];
                        return AnimatedEntrance(
                          index: index,
                          child: StallCard(
                            vendor: vendor,
                            selectedCategory: _selectedCategory,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Pill chip for top-level market categories (All, Fresh Fish, Meat, etc.).
class MarketCategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const MarketCategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: isSelected
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 1,
                ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.12),
                    offset: Offset(0, 3),
                    blurRadius: 6,
                    spreadRadius: -1,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppTheme.primaryGreen : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Small pill chip for Meat subcategories (All, Beef, Pork).
class MarketSubcategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const MarketSubcategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: isSelected
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppTheme.primaryGreen : Colors.white,
          ),
        ),
      ),
    );
  }
}
