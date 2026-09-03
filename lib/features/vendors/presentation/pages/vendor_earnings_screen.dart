import 'dart:isolate';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/features/vendors/application/sales_report_export_service.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/vendors/application/vendor_orders_provider.dart';

import 'package:palengkego/core/utils/file_export_util.dart';
import 'package:palengkego/features/vendors/application/vendor_earnings_provider.dart';
import 'package:palengkego/features/vendors/domain/sales_summary.dart';

// ── Per-period view model, computed from real salesSummary rollups ───────────

class _PeriodData {
  final String total;
  final String change;
  final bool isPositive;
  final List<String> labels;
  final List<double> values; // 0.0–1.0 relative to max
  final int highlightIndex;

  const _PeriodData({
    required this.total,
    required this.change,
    required this.isPositive,
    required this.labels,
    required this.values,
    required this.highlightIndex,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class VendorEarningsScreen extends ConsumerStatefulWidget {
  const VendorEarningsScreen({super.key});

  @override
  ConsumerState<VendorEarningsScreen> createState() =>
      _VendorEarningsScreenState();
}

class _VendorEarningsScreenState extends ConsumerState<VendorEarningsScreen> {
  String _selectedTab = 'Today';

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Builds the period view from REAL daily rollups (trusted backend
  /// `salesSummary` docs). Zero sales render as honest zeros — figures are
  /// never fabricated.
  _PeriodData _buildPeriodData(List<SalesSummary> summaries) {
    final byDay = {
      for (final s in summaries)
        DateTime(s.date.year, s.date.month, s.date.day): s.totalRevenue,
    };
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    double revenueOn(DateTime day) =>
        byDay[DateTime(day.year, day.month, day.day)] ?? 0;
    double sumRange(int daysBack, int length) {
      var sum = 0.0;
      for (var i = 0; i < length; i++) {
        sum += revenueOn(todayKey.subtract(Duration(days: daysBack + i)));
      }
      return sum;
    }

    List<double> seriesFor(int daysBack, int length) => List.generate(
          length,
          (i) => revenueOn(todayKey.subtract(Duration(days: daysBack + i))),
        ).reversed.toList();
    List<String> labelsFor(int daysBack, int length) => List.generate(
          length,
          (i) => _weekdayLabels[todayKey
                  .subtract(Duration(days: daysBack + i))
                  .weekday -
              1],
        ).reversed.toList();

    if (_selectedTab == 'Week') {
      return _make(
        total: sumRange(0, 7),
        previous: sumRange(7, 7),
        vs: 'last week',
        labels: labelsFor(0, 7),
        values: seriesFor(0, 7),
      );
    }
    if (_selectedTab == 'Month') {
      // Four week-sized buckets over the last 28 days.
      final daily = seriesFor(0, 28);
      final values = <double>[
        for (var w = 0; w < 4; w++)
          daily.sublist(w * 7, w * 7 + 7).fold(0.0, (a, b) => a + b),
      ];
      return _make(
        total: sumRange(0, 28),
        previous: sumRange(28, 28),
        vs: 'last 4 weeks',
        labels: const ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'],
        values: values,
      );
    }
    // Today: the total is today only; the chart honestly shows the last 7
    // days (daily rollups have no intraday granularity).
    return _make(
      total: revenueOn(todayKey),
      previous: revenueOn(todayKey.subtract(const Duration(days: 1))),
      vs: 'yesterday',
      labels: labelsFor(0, 7),
      values: seriesFor(0, 7),
    );
  }

  _PeriodData _make({
    required double total,
    required double previous,
    required String vs,
    required List<String> labels,
    required List<double> values,
  }) {
    String peso(double v) => '₱${v.toStringAsFixed(2)}';
    final maxVal = values.fold(0.0, (a, b) => a > b ? a : b);
    final diff = total - previous;
    return _PeriodData(
      total: peso(total),
      change: total == 0 && previous == 0
          ? 'No completed sales yet'
          : '${diff >= 0 ? '+' : '−'}${peso(diff.abs())} vs $vs',
      isPositive: diff >= 0,
      labels: labels,
      values:
          maxVal <= 0 ? List.filled(values.length, 0.0) : [for (final v in values) v / maxVal],
      highlightIndex: values.length - 1,
    );
  }

  /// Honest range label under the chart title.
  String get _rangeLabel {
    final now = DateTime.now();
    String d(DateTime x) =>
        '${x.month}/${x.day}${x.year != now.year ? '/${x.year}' : ''}';
    switch (_selectedTab) {
      case 'Week':
        return '${d(now.subtract(const Duration(days: 6)))} – ${d(now)}';
      case 'Month':
        return '${d(now.subtract(const Duration(days: 27)))} – ${d(now)}';
      default:
        return 'Last 7 days (through ${d(now)})';
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(vendorDailySalesProvider);

    return AuthGuard(
      allowedRoles: {UserRole.vendor},
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        body: salesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          ),
          error: (e, _) => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 44, color: AppTheme.muted),
                  SizedBox(height: 12),
                  Text(
                    'Earnings are unavailable right now.\nPlease try again later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          ),
          data: (summaries) => _buildContent(_buildPeriodData(summaries)),
        ),
      ),
    );
  }

  Widget _buildContent(_PeriodData data) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppTheme.scaffoldBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Earnings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showExportDialog,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.file_download_outlined,
                      size: 20,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Period tabs ──────────────────────────────────────────────
            Row(
              children: [
                _buildTab('Today'),
                const SizedBox(width: 8),
                _buildTab('Week'),
                const SizedBox(width: 8),
                _buildTab('Month'),
              ],
            ),
            const SizedBox(height: 20),

            // ── Total earnings card — animates on tab change ─────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.06),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                      ),
                  child: child,
                ),
              ),
              child: _EarningsCard(
                key: ValueKey(_selectedTab),
                total: data.total,
                change: data.change,
                isPositive: data.isPositive,
              ),
            ),
            const SizedBox(height: 24),

            // ── Bar chart ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Sales',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      key: ValueKey('${_selectedTab}label'),
                      _rangeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Animated bar chart
            _AnimatedBarChart(
              key: ValueKey(_selectedTab),
              labels: data.labels,
              values: data.values,
              highlightIndex: data.highlightIndex,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _showExportDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Export Sales Report',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf,
                  color: Color(0xFFEF4444),
                ),
                title: const Text(
                  'Export as PDF',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _exportToPdf();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.table_chart,
                  color: AppTheme.primaryGreen,
                ),
                title: const Text(
                  'Export as Excel',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _exportToExcel();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportToPdf() async {
    try {
      final stallName = ref.read(vendorStallProvider).name;
      final orders = (ref.read(vendorOrdersProvider).value ?? [])
          .where((o) => o.status == OrderStatus.completed)
          .toList();
      final bytes = await Isolate.run(() => SalesReportExportService.buildPdf(
        _selectedTab,
        stallName,
        orders,
      ));
      final filename = SalesReportExportService.buildFilename(
        _selectedTab,
        DateTime.now(),
        stallName,
      );

      final path = await FileExportUtil.saveFileToPublicDirectory(
        filename: '$filename.pdf',
        bytes: bytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved directly to: $path'),
          backgroundColor: AppTheme.primaryGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final stallName = ref.read(vendorStallProvider).name;
      final orders = (ref.read(vendorOrdersProvider).value ?? [])
          .where((o) => o.status == OrderStatus.completed)
          .toList();
      final fileBytes = await Isolate.run(() => SalesReportExportService.buildExcel(
        _selectedTab,
        stallName,
        orders,
      ));
      final filename = SalesReportExportService.buildFilename(
        _selectedTab,
        DateTime.now(),
        stallName,
      );

      final path = await FileExportUtil.saveFileToPublicDirectory(
        filename: '$filename.xlsx',
        bytes: fileBytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel saved directly to: $path'),
          backgroundColor: AppTheme.primaryGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export Excel: $e')));
    }
  }

  Widget _buildTab(String label) {
    final isSelected = _selectedTab == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Earnings card ─────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  final String total;
  final String change;
  final bool isPositive;

  const _EarningsCard({
    super.key,
    required this.total,
    required this.change,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Earnings',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.accentGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            total,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isPositive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 12,
                color: isPositive
                    ? AppTheme.accentGreen
                    : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 4),
              Text(
                change,
                style: TextStyle(
                  fontSize: 12,
                  color: isPositive
                      ? AppTheme.accentGreen
                      : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Animated bar chart ────────────────────────────────────────────────────────

class _AnimatedBarChart extends StatefulWidget {
  final List<String> labels;
  final List<double> values;
  final int highlightIndex;

  const _AnimatedBarChart({
    super.key,
    required this.labels,
    required this.values,
    required this.highlightIndex,
  });

  @override
  State<_AnimatedBarChart> createState() => _AnimatedBarChartState();
}

class _AnimatedBarChartState extends State<_AnimatedBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _barAnimations;

  static const double _maxBarHeight = 70.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _buildAnimations();
    _controller.forward();
  }

  void _buildAnimations() {
    _barAnimations = List.generate(widget.values.length, (i) {
      final start = i / widget.values.length * 0.4;
      return Tween<double>(begin: 0, end: widget.values[i]).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            start,
            (start + 0.6).clamp(0, 1),
            curve: Curves.easeOut,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 136,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.labels.length, (i) {
              final isHighlighted = i == widget.highlightIndex;
              final barH = _maxBarHeight * _barAnimations[i].value;

              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Value label above highlighted bar
                    if (isHighlighted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _topLabel(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 20),

                    // Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          height: barH.clamp(4, _maxBarHeight),
                          decoration: BoxDecoration(
                            color: isHighlighted
                                ? AppTheme.primaryGreen
                                : AppTheme.border,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Label
                    Text(
                      widget.labels[i],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isHighlighted
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isHighlighted
                            ? AppTheme.primaryGreen
                            : AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }

  String _topLabel() {
    // Show a short representative value for the highlighted bar's peak
    final val = widget.values[widget.highlightIndex];
    if (val >= 0.9) return 'Peak';
    if (val >= 0.7) return 'High';
    return 'Top';
  }
}
