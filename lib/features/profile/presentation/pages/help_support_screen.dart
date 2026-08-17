import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/widgets/app_screen_header.dart';

class CustomerHelpSupportScreen extends StatefulWidget {
  const CustomerHelpSupportScreen({super.key});

  @override
  State<CustomerHelpSupportScreen> createState() =>
      _CustomerHelpSupportScreenState();
}

class _CustomerHelpSupportScreenState extends State<CustomerHelpSupportScreen> {
  final _reportFormKey = GlobalKey<FormState>();
  final _reportController = TextEditingController();
  String _selectedTopic = 'Order Issue';

  final List<String> _topics = [
    'Order Issue',
    'Delivery Problem',
    'Payment Problem',
    'App Issue',
    'Other',
  ];

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  void _submitReport() {
    if (_reportFormKey.currentState!.validate()) {
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
              Text(
                'Report Submitted',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          content: Text(
            'Thank you for reaching out. Our support team has received your ticket regarding "$_selectedTopic" and will review it shortly.',
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const AppScreenHeader(title: 'Help & Support'),
            Expanded(
              child: SingleChildScrollView(
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
                                onPressed: _submitReport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
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
