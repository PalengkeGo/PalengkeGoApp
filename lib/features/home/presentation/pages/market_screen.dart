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
      body: Stack(
        children: [
          // Emerald Gradient Header Background fading seamlessly downwards
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 240,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0B372B),
                    Color(0xFF114234),
                    Color(0xFF1A4D3D),
                    Color(0xFF265F4C),
                    Color(0xFF3B7B64),
                    Color(0xFF64A18B),
                    Color(0xFF9DC7B7),
                    Color(0xFFE5F0EB),
                    Colors.white,
                  ],
                  stops: [0.0, 0.20, 0.40, 0.55, 0.70, 0.82, 0.91, 0.96, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const HomeHeader(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 6, 20, 14),
                  child: SearchField(isInline: true),
                ),
                Expanded(
                  child: query.trim().isEmpty
                      ? const MarketStallBrowser()
                      : MarketCombinedSearchResults(query: query),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
