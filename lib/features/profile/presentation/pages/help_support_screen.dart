import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_screen_header.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/reports/data/reports_repository.dart';
import 'package:palengkego/features/reports/domain/user_report.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerHelpSupportScreen extends ConsumerStatefulWidget {
  const CustomerHelpSupportScreen({super.key});

  @override
  ConsumerState<CustomerHelpSupportScreen> createState() =>
      _CustomerHelpSupportScreenState();
}

class _CustomerHelpSupportScreenState
    extends ConsumerState<CustomerHelpSupportScreen> {
  final _reportFormKey = GlobalKey<FormState>();
  final _reportController = TextEditingController();
  String _selectedTopic = 'Order Issue';
  bool _isSubmitting = false;
  RealtimeChannel? _realtimeChannel;

  final List<String> _topics = [
    'Order Issue',
    'Delivery Problem',
    'Payment Problem',
    'App Issue',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRealtimeSubscription();
    });
  }

  void _initRealtimeSubscription() {
    final uid = ref.read(authProvider)?.uid;
    if (uid != null && uid.isNotEmpty) {
      _realtimeChannel = ref.read(reportsRepositoryProvider).subscribeToUserReports(
        userId: uid,
        onUpdate: (_) {
          if (mounted) setState(() {});
        },
      );
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_reportFormKey.currentState!.validate() || _isSubmitting) return;

    final topic = _selectedTopic;
    final text = _reportController.text.trim();
    final user = ref.read(authProvider);

    setState(() => _isSubmitting = true);

    final reportId = 'RPT-${DateTime.now().millisecondsSinceEpoch}';
    final report = UserReport(
      id: reportId,
      userId: user?.uid,
      type: 'Customer',
      accountIssue: topic,
      category: topic,
      submittedBy: user?.displayName ?? 'Customer',
      reason: topic,
      description: text,
      reporterEmail: user?.email ?? '',
      phone: user?.phoneNumber ?? '',
      status: 'pending',
      priority:
          topic.contains('Payment') || topic.contains('Order') ? 'high' : 'medium',
      createdAt: DateTime.now(),
    );

    await ref.read(reportsRepositoryProvider).submitReport(report);

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _reportController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppTheme.statusOpen,
              size: 24,
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Report Submitted',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Thank you for reaching out. Your report has been dispatched to administrators under Ticket #$reportId. You can track status and administrator replies below.',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final userId = user?.uid ?? '';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const AppScreenHeader(title: 'Help & Support'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                color: AppTheme.primaryGreen,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Title: FAQs
                    const Text(
                      'Frequently Asked Questions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildFaqTile(
                      question: 'How do I track my order?',
                      answer:
                          'Go to the Orders tab in the main navigation or tap "Track Order" on your active order card to view real-time status updates.',
                    ),
                    _buildFaqTile(
                      question: 'What payment methods are supported?',
                      answer:
                          'We support Cash on Delivery (COD) as well as credit/debit card payments.',
                    ),
                    _buildFaqTile(
                      question: 'How does market delivery work?',
                      answer:
                          'Our riders pick up your fresh items directly from local stall holders in the wet market and deliver them straight to your specified address.',
                    ),
                    _buildFaqTile(
                      question: 'Can I cancel my order?',
                      answer:
                          'Orders can be cancelled within 2 minutes of placing them (before stall holder confirmation) directly from the Order Details screen.',
                    ),
                    _buildFaqTile(
                      question: 'How do I contact a stall holder?',
                      answer:
                          'You can view stall details on your active order page or vendor profile page and tap "Call Stall Holder" to reach them directly.',
                    ),

                    const SizedBox(height: 32),

                    // Section Title: Contact Support
                    const Text(
                      'Contact Support',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildContactRow(
                      icon: Icons.email_outlined,
                      label: 'Email Us',
                      value: 'support@palengkego.ph',
                    ),
                    const SizedBox(height: 12),
                    _buildContactRow(
                      icon: Icons.phone_outlined,
                      label: 'Call Us',
                      value: '+63 917 999 8888',
                    ),

                    const SizedBox(height: 32),

                    // Section Title: Report a Problem
                    const Text(
                      'Report a Problem',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Form(
                        key: _reportFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Topic',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedTopic,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                              items: _topics
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(
                                        t,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedTopic = val);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Describe the Issue',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            AppTextField(
                              controller: _reportController,
                              maxLines: 4,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please describe the issue.';
                                }
                                return null;
                              },
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1E293B),
                              ),
                              hintText: 'Explain the issue in detail...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.muted,
                              ),
                              borderRadius: 10,
                              borderColor: const Color(0xFFCBD5E1),
                              focusedBorderWidth: 2,
                              contentPadding: const EdgeInsets.all(14),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitReport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Submit Report',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Section Title: My Submitted Tickets with Refresh action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Submitted Tickets',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                          tooltip: 'Refresh tickets',
                          onPressed: () => setState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    FutureBuilder<List<UserReport>>(
                      future: ref
                          .read(reportsRepositoryProvider)
                          .getUserReports(userId, email: email),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          );
                        }

                        final reports = snapshot.data ?? [];
                        if (reports.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 32,
                                  color: Color(0xFF94A3B8),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No submitted tickets yet.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: reports.map((r) => _buildReportCard(r)).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(UserReport report) {
    final statusBg = switch (report.status.toLowerCase()) {
      'resolved' => const Color(0xFFDCFCE7),
      'underreview' || 'under_review' => const Color(0xFFDBEAFE),
      'dismissed' => const Color(0xFFF1F5F9),
      _ => const Color(0xFFFEF3C7),
    };
    final statusText = switch (report.status.toLowerCase()) {
      'resolved' => const Color(0xFF166534),
      'underreview' || 'under_review' => const Color(0xFF1E40AF),
      'dismissed' => const Color(0xFF475569),
      _ => const Color(0xFF92400E),
    };
    final statusLabel = switch (report.status.toLowerCase()) {
      'resolved' => 'Resolved',
      'underreview' || 'under_review' => 'Under Review',
      'dismissed' => 'Dismissed',
      _ => 'Pending',
    };

    final adminResponse = (report.resolutionNote != null &&
            report.resolutionNote!.trim().isNotEmpty)
        ? report.resolutionNote!.trim()
        : (report.notes.trim().isNotEmpty ? report.notes.trim() : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ticket #${report.id.length > 12 ? report.id.substring(report.id.length - 8) : report.id}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            report.reason.isNotEmpty ? report.reason : report.category,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            report.description,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMM dd, yyyy • h:mm a').format(report.createdAt),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
          if (adminResponse != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.support_agent_rounded,
                        size: 16,
                        color: Color(0xFF15803D),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Admin Response (${report.decision ?? (report.isResolved ? 'Resolved' : 'Update')}):',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adminResponse,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF166534),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFaqTile({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppTheme.primaryGreen,
          collapsedIconColor: AppTheme.textSecondary,
          title: Text(
            question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  answer,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
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
