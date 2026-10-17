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
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A604B), Color(0xFF064333)],
              ),
            ),
            child: const SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HomeHeader(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 6, 20, 14),
                    child: SearchField(isInline: true),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: query.trim().isEmpty
                ? const MarketStallBrowser()
                : MarketCombinedSearchResults(query: query),
          ),
        ],
      ),
    );
  }
}
