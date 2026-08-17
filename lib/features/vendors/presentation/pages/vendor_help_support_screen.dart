import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/core/widgets/app_screen_header.dart';

class VendorHelpSupportScreen extends StatefulWidget {
  const VendorHelpSupportScreen({super.key});

  @override
  State<VendorHelpSupportScreen> createState() =>
      _VendorHelpSupportScreenState();
}

class _VendorHelpSupportScreenState extends State<VendorHelpSupportScreen> {
  final _reportFormKey = GlobalKey<FormState>();
  final _reportController = TextEditingController();
  String _selectedTopic = 'App Issue';

  final List<String> _topics = [
    'App Issue',
    'Payout/Earnings',
    'Order Management',
    'Customer Conflict',
    'Other Support',
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
            'Thank you for reporting. Our support team has received your ticket regarding "$_selectedTopic" and will review it shortly.',
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
    return AuthGuard(
      allowedRoles: {UserRole.vendor},
      child: Scaffold(
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

                      // Flat FAQ Expansion tiles
                      _buildFaqTile(
                        question: 'How do I update my products?',
                        answer:
                            'Go to the Inventory tab in your dashboard, tap the edit icon on the product you want to change, and update the details, price, or stock status.',
                      ),
                      _buildFaqTile(
                        question: 'How do I manage orders?',
                        answer:
                            'Active orders will show up in your Orders tab. Tap an order to view items, and change the status (e.g., Prepared, Ready for Pickup) as you process it.',
                      ),
                      _buildFaqTile(
                        question: 'How do payouts work?',
                        answer:
                            'Payouts are processed weekly every Monday directly to your registered bank account. You can track all your transactions in the Earnings page.',
                      ),
                      _buildFaqTile(
                        question: 'Can I change my stall location?',
                        answer:
                            'Stall locations are assigned by the market administration. If you need to relocate, please contact the support team or visit the administration office.',
                      ),
                      _buildFaqTile(
                        question: 'How do I contact a customer?',
                        answer:
                            "On the order details page of an active order, tap the phone/chat icon next to the customer's name to contact them directly regarding their order.",
                      ),

                      const SizedBox(height: 32),

                      // Section Title: Contact Us
                      const Text(
                        'Contact Support',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Contact Rows
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

                      // Report Form Card
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
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _showTopicPicker(context),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedTopic,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: AppTheme.textSecondary,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Describe the Issue',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 8),
                              AppTextField(
                                controller: _reportController,
                                maxLines: 4,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                                hintText: 'Explain the issue in detail...',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.muted,
                                ),
                                borderRadius: 10,
                                borderColor: const Color(0xFFCBD5E1),
                                contentPadding: const EdgeInsets.all(12),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please provide a description of the issue';
                                  }
                                  if (val.trim().length < 10) {
                                    return 'Please explain in at least 10 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: _submitReport,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Submit Report',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqTile({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              color: AppTheme.textPrimary,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.5,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTopicPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Select Topic',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              ..._topics.map((topic) {
                return ListTile(
                  title: Text(
                    topic,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  trailing: _selectedTopic == topic
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppTheme.primaryGreen,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedTopic = topic;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
