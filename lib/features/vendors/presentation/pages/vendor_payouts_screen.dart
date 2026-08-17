import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';

// ── Mock payout data ──────────────────────────────────────────────────────────

class _Payout {
  final String method;
  final String date;
  final double amount;

  const _Payout({
    required this.method,
    required this.date,
    required this.amount,
  });
}

const _mockPayouts = [
  _Payout(method: 'Bank Transfer', date: 'May 21, 2024', amount: 4900.00),
  _Payout(method: 'Bank Transfer', date: 'May 14, 2024', amount: 5850.00),
  _Payout(method: 'Bank Transfer', date: 'Apr 29, 2024', amount: 4100.00),
  _Payout(method: 'Bank Transfer', date: 'Apr 22, 2024', amount: 6250.00),
  _Payout(method: 'Bank Transfer', date: 'Apr 08, 2024', amount: 3780.00),
  _Payout(method: 'Bank Transfer', date: 'Mar 25, 2024', amount: 5500.00),
  _Payout(method: 'Bank Transfer', date: 'Mar 11, 2024', amount: 4200.00),
  _Payout(method: 'Bank Transfer', date: 'Feb 27, 2024', amount: 6800.00),
  _Payout(method: 'Bank Transfer', date: 'Feb 13, 2024', amount: 3950.00),
  _Payout(method: 'Bank Transfer', date: 'Jan 30, 2024', amount: 5100.00),
  _Payout(method: 'Bank Transfer', date: 'Jan 16, 2024', amount: 4650.00),
  _Payout(method: 'Bank Transfer', date: 'Jan 02, 2024', amount: 3300.00),
];

// ── Screen ────────────────────────────────────────────────────────────────────

/// Full payout history screen.
/// Data comes from the unified mock repository — swap [_mockPayouts] for a
/// provider call when the backend is ready. No BuildContext used in async gaps.
class VendorPayoutsScreen extends StatelessWidget {
  const VendorPayoutsScreen({super.key});

  double get _totalPaid => _mockPayouts.fold(0.0, (sum, p) => sum + p.amount);

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      allowedRoles: {UserRole.vendor},
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppTheme.primaryGreen,
            ),
          ),
          title: const Text(
            'Payout History',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
          centerTitle: false,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Summary card ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _SummaryCard(
                  totalPaid: _totalPaid,
                  count: _mockPayouts.length,
                ),
              ),
            ),

            // ── Section label ─────────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'All Payouts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.muted,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

            // ── Payout list ───────────────────────────────────────────────────
            SliverList.separated(
              itemCount: _mockPayouts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final isLast = index == _mockPayouts.length - 1;
                return Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, isLast ? 24 : 0),
                  child: _PayoutCard(payout: _mockPayouts[index]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double totalPaid;
  final int count;

  const _SummaryCard({required this.totalPaid, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Paid Out',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.accentGreen,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '₱${totalPaid.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'payouts',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payout card ───────────────────────────────────────────────────────────────

class _PayoutCard extends StatelessWidget {
  final _Payout payout;

  const _PayoutCard({required this.payout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.account_balance_rounded,
              color: AppTheme.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Method + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payout.method,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  payout.date,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),

          // Amount + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${payout.amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
