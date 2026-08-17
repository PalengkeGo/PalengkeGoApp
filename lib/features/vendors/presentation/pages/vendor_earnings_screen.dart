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
// ── Per-period mock data ──────────────────────────────────────────────────────

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

const _todayData = _PeriodData(
  total: '₱2,450.00',
  change: '+₱320 vs yesterday',
  isPositive: true,
  labels: ['8am', '10am', '12pm', '2pm', '4pm', '6pm', '8pm'],
  values: [0.20, 0.35, 0.85, 0.60, 0.45, 0.95, 0.30],
  highlightIndex: 5, // 6pm peak
);

const _weekData = _PeriodData(
  total: '₱12,450.00',
  change: '+₱1,250 vs last week',
  isPositive: true,
  labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  values: [0.30, 0.50, 0.40, 0.80, 0.60, 0.95, 0.40],
  highlightIndex: 5, // Saturday
);

const _monthData = _PeriodData(
  total: '₱48,200.00',
  change: '+₱5,800 vs last month',
  isPositive: true,
  labels: ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'],
  values: [0.65, 0.80, 0.55, 1.00],
  highlightIndex: 3, // current week
);

// ── Screen ────────────────────────────────────────────────────────────────────

class VendorEarningsScreen extends ConsumerStatefulWidget {
  const VendorEarningsScreen({super.key});

  @override
  ConsumerState<VendorEarningsScreen> createState() =>
      _VendorEarningsScreenState();
}

class _VendorEarningsScreenState extends ConsumerState<VendorEarningsScreen> {
  String _selectedTab = 'Today';

  _PeriodData get _currentData {
    if (_selectedTab == 'Week') return _weekData;
    if (_selectedTab == 'Month') return _monthData;
    return _todayData;
  }

  @override
  Widget build(BuildContext context) {
    final data = _currentData;

    return AuthGuard(
      allowedRoles: {UserRole.vendor},
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        body: SafeArea(
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
                          _selectedTab == 'Today'
                              ? 'Today, Jun 18'
                              : _selectedTab == 'Week'
                              ? 'Jun 12 - Jun 18'
                              : 'June 2024',
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
      final bytes = await SalesReportExportService.buildPdf(
        _selectedTab,
        stallName,
        orders,
      );
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
      final fileBytes = SalesReportExportService.buildExcel(
        _selectedTab,
        stallName,
        orders,
      );
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
