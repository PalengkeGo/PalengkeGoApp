import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/market/application/market_provider.dart';
import 'package:palengkego/features/market/domain/market_product.dart';
import 'package:palengkego/features/market/domain/market_vendor.dart';
import 'package:palengkego/features/profile/application/blocked_vendors_provider.dart';

class AppSearchResult {
  final MarketProduct? product;
  final MarketVendor? vendor;
  AppSearchResult({this.product, this.vendor});
  bool get isProduct => product != null;
}

/// Holds the current search query string typed in the search bar.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String raw) => state = sanitize(raw);
  void clear() {
    if (!ref.mounted) return;
    state = '';
  }

  /// Strips characters that have no business in a search query:
  /// HTML tags, script injection characters (<>{}), and control chars.
  /// Also collapses repeated whitespace and caps length at 100.
  static String sanitize(String raw) {
    var s = raw
        .replaceAll(RegExp(r'[<>{}\[\]\\|^`]'), '') // strip injection chars
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // strip control chars
        .replaceAll(RegExp(r'\s+'), ' ') // collapse whitespace
        .trimLeft(); // no leading space
    if (s.length > 100) s = s.substring(0, 100);
    return s;
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// Holds the currently selected subcategory (e.g. 'Beef', 'Pork', or 'All').
class SelectedSubcategoryNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setSubcategory(String value) => state = value;
}

final selectedSubcategoryProvider =
    NotifierProvider<SelectedSubcategoryNotifier, String>(
      SelectedSubcategoryNotifier.new,
    );

/// Filtered vendor list based on the current search query + selected category + selected subcategory.
/// When query is empty, returns the full category-filtered list, excluding blocked vendors.
final filteredVendorsProvider =
    Provider.family<AsyncValue<List<MarketVendor>>, String>((ref, category) {
      final query = ref.watch(searchQueryProvider).toLowerCase().trim();
      final blockedIds = ref.watch(blockedVendorsProvider);
      final vendorsAsync = ref.watch(vendorsByCategoryProvider(category));

      return vendorsAsync.whenData((vendors) {
        final subcategory = ref.watch(selectedSubcategoryProvider);
        var filtered = vendors
            .where((v) => !blockedIds.contains(v.id))
            .toList();

        if (subcategory != 'All') {
          filtered = filtered
              .where((v) => v.tags?.contains(subcategory) ?? false)
              .toList();
        }

        if (query.isEmpty) return filtered;
        return filtered.where((v) {
          return v.name.toLowerCase().contains(query) ||
              v.category.toLowerCase().contains(query);
        }).toList();
      });
    });

final appSearchProvider = FutureProvider.family<List<AppSearchResult>, String>((
  ref,
  rawQuery,
) async {
  final query = SearchQueryNotifier.sanitize(rawQuery).toLowerCase();
  if (query.isEmpty) return [];

  final productsAsync = ref.watch(searchProductsProvider(query).future);
  final vendorsAsync = ref.watch(searchVendorsProvider(query).future);

  final results = await Future.wait([productsAsync, vendorsAsync]);
  final products = results[0] as List<MarketProduct>;
  final vendors = results[1] as List<MarketVendor>;

  final List<AppSearchResult> combined = [];
  for (var v in vendors) {
    combined.add(AppSearchResult(vendor: v));
  }
  for (var p in products) {
    combined.add(AppSearchResult(product: p));
  }
  return combined;
});
