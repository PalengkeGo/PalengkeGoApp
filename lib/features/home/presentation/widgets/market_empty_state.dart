import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';

/// Empty state for the market: no stalls (browse mode) or no search results.
class MarketEmptyState extends StatelessWidget {
  final String query;

  const MarketEmptyState({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off,
      iconBackground: const Color(0xFFE8F5E9),
      iconColor: AppTheme.accentGreen,
      iconSize: 36,
      iconContainerRadius: 36,
      iconSpacing: 16,
      title: query.isEmpty ? 'No stalls available' : 'No results for "$query"',
      titleStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryGreen,
      ),
      subtitle: 'Try a different stall name, product, or category.',
      subtitleStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
    );
  }
}
