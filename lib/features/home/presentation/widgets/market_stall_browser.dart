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
        Container(
          color: Colors.white,
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
              ? Container(
                  color: Colors.white,
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
        const Divider(
          height: 1,
          thickness: 1,
          color: AppTheme.surfaceContainerLow,
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stalls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
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

/// Pill-style category chip used in the market stall browser.
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
              ? AppTheme.primaryGreen
              : AppTheme.scaffoldBackground,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.1),
                    offset: Offset(0, 4),
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
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.accentGreen,
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
          color: isSelected ? AppTheme.accentGreen : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.primaryGreen,
          ),
        ),
      ),
    );
  }
}
