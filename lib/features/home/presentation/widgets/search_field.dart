import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:palengkego/features/market/domain/market_product.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/home/application/search_provider.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/navigation/app_router.dart';

class SearchField extends ConsumerStatefulWidget {
  final bool isInline;
  const SearchField({super.key, this.isInline = false});

  @override
  ConsumerState<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<SearchField> {
  late final TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initialText = widget.isInline ? ref.read(searchQueryProvider) : '';
    _ctrl = TextEditingController(text: initialText);
    _query = initialText;
    _ctrl.addListener(_onTextChanged);
    _focus.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    final text = _ctrl.text;
    if (text != _query) {
      setState(() => _query = text);
      if (widget.isInline) {
        ref.read(searchQueryProvider.notifier).update(text);
      } else {
        _overlay?.markNeedsBuild();
      }
    }
  }

  void _onFocusChanged() {
    if (widget.isInline) return;
    if (_focus.hasFocus) {
      _showOverlay();
    } else {
      // Delay so a tap on an overlay result tile can complete before removal.
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focus.hasFocus) {
          _hideOverlay();
          setState(() {});
        }
      });
    }
  }

  void _showOverlay() {
    if (_overlay != null) return;
    _overlay = _buildOverlayEntry();
    Overlay.of(context).insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _handleSubmit(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    _focus.unfocus();
    _hideOverlay();
    Navigator.pushNamed(
      context,
      AppRoutes.recommendedIngredientStores,
      arguments: RecommendedIngredientStoresRouteArgs(ingredientName: text),
    );
  }

  void _clear() {
    _ctrl.clear();
    setState(() => _query = '');
    if (widget.isInline) {
      ref.read(searchQueryProvider.notifier).clear();
    } else {
      _overlay?.markNeedsBuild();
    }
  }

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (ctx) => _SearchDropdown(
        layerLink: _layerLink,
        query: _ctrl.text,
        onSelect: (result) {
          _focus.unfocus();
          _hideOverlay();
          final vendorId = result.isProduct
              ? result.product!.vendorId
              : result.vendor!.id;
          Navigator.pushNamed(
            context,
            AppRoutes.vendorProfile,
            arguments: VendorProfileRouteArgs(vendorId: vendorId),
          );
        },
        onSeeAll: () {
          _handleSubmit(_ctrl.text);
        },
        onQueryChanged: () => _query,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _focus.removeListener(_onFocusChanged);
    _hideOverlay();
    _ctrl.dispose();
    _focus.dispose();
    if (widget.isInline) {
      Future.microtask(() {
        if (mounted) ref.read(searchQueryProvider.notifier).clear();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        decoration: BoxDecoration(
          color: _focus.hasFocus ? Colors.white : AppTheme.scaffoldBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _focus.hasFocus
                ? AppTheme.primaryGreen.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _focus.hasFocus
                  ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                  : const Color(0xFF000000).withValues(alpha: 0.04),
              offset: const Offset(0, 2),
              blurRadius: _focus.hasFocus ? 12 : 4,
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            GestureDetector(
              onTap: () => _handleSubmit(_ctrl.text),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.search_rounded,
                  key: ValueKey(_focus.hasFocus),
                  size: 18,
                  color: _focus.hasFocus
                      ? AppTheme.primaryGreen
                      : AppTheme.accentGreen,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onSubmitted: _handleSubmit,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).searchHint,
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.muted,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: _clear,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

// ── Overlay dropdown ─────────────────────────────────────────────────────────

class _SearchDropdown extends ConsumerWidget {
  final LayerLink layerLink;
  final String query;
  final ValueChanged<AppSearchResult> onSelect;
  final VoidCallback onSeeAll;
  final String Function() onQueryChanged;

  const _SearchDropdown({
    required this.layerLink,
    required this.query,
    required this.onSelect,
    required this.onSeeAll,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().isEmpty) return const SizedBox.shrink();
    final resultsAsync = ref.watch(appSearchProvider(query));
    return Positioned(
      width: MediaQuery.of(context).size.width,
      child: CompositedTransformFollower(
        link: layerLink,
        showWhenUnlinked: false,
        offset: const Offset(
          -20,
          52,
        ), // sits just below the search bar, perfectly aligned
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: resultsAsync.when(
                  loading: () => const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, stack) => _emptyState('Error: $err'),
                  data: (results) {
                    if (results.isEmpty) {
                      return _emptyState(query);
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemCount: results.length,
                            separatorBuilder: (_, index) => const Divider(
                              height: 1,
                              indent: 72,
                              endIndent: 16,
                              color: Color(0xFFF1F5F4),
                            ),
                            itemBuilder: (_, i) {
                              final result = results[i];
                              if (result.isProduct) {
                                return _ProductResultTile(
                                  product: result.product!,
                                  onTap: () => onSelect(result),
                                );
                              } else {
                                return _VendorResultTile(
                                  vendor: result.vendor!,
                                  onTap: () => onSelect(result),
                                );
                              }
                            },
                          ),
                        ),
                        InkWell(
                          onTap: onSeeAll,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: const BoxDecoration(
                              color: AppTheme.surface,
                              border: Border(
                                top: BorderSide(color: AppTheme.border),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.grid_view_rounded,
                                  size: 14,
                                  color: AppTheme.primaryGreen,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'See full 2-column results for "$query"',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: AppTheme.primaryGreen,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String q) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Row(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 20,
            color: Color(0xFFCBD5E1),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No results for "$q"',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual result tile ────────────────────────────────────────────────────

class _ProductResultTile extends ConsumerWidget {
  final MarketProduct product;
  final VoidCallback onTap;

  const _ProductResultTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorAsync = ref.watch(vendorProfileProvider(product.vendorId));

    return InkWell(
      onTap: onTap,
      splashColor: AppTheme.primaryGreen.withValues(alpha: 0.06),
      highlightColor: AppTheme.primaryGreen.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AdaptiveImage(
                product.imageUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                placeholder: Container(
                  width: 44,
                  height: 44,
                  color: const Color(0xFFF3F4F6),
                  child: const Icon(
                    Icons.image_rounded,
                    size: 18,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + vendor
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vendorAsync.when(
                      data: (v) => v.name,
                      loading: () => product.category,
                      error: (e, _) => product.category,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Price + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₱${product.discountedPrice.toStringAsFixed(0)}/${product.unit}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorResultTile extends StatelessWidget {
  final MarketVendor vendor;
  final VoidCallback onTap;

  const _VendorResultTile({required this.vendor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppTheme.primaryGreen.withValues(alpha: 0.06),
      highlightColor: AppTheme.primaryGreen.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AdaptiveImage(
                vendor.imageUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                placeholder: Container(
                  width: 44,
                  height: 44,
                  color: const Color(0xFFF3F4F6),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 18,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + category
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vendor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Stall Holder',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Category + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vendor.category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}
