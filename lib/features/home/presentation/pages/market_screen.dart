import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/home/application/search_provider.dart';
import 'package:palengkego/features/home/presentation/widgets/home_header.dart';
import 'package:palengkego/features/home/presentation/widgets/search_field.dart';
import 'package:palengkego/features/home/presentation/widgets/market_stall_browser.dart';
import 'package:palengkego/features/home/presentation/widgets/market_search_results.dart';

class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const HomeHeader(),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: const SearchField(isInline: true),
            ),
            const Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.surfaceContainerLow,
            ),
            Expanded(
              child: query.trim().isEmpty
                  ? const MarketStallBrowser()
                  : MarketCombinedSearchResults(query: query),
            ),
          ],
        ),
      ),
    );
  }
}
