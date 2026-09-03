import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/app_text_field.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/mock/mock_data.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_review.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_reviews_provider.dart'
    as vr;
import 'package:palengkego/core/widgets/login_required_sheet.dart';
import 'package:palengkego/features/profile/application/profile_provider.dart';

class RatingModal extends ConsumerStatefulWidget {
  final MarketOrder order;

  const RatingModal({super.key, required this.order});

  static void show(BuildContext context, MarketOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.6),
      builder: (context) => RatingModal(order: order),
    );
  }

  @override
  ConsumerState<RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends ConsumerState<RatingModal> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 24,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              ClipOval(
                child: AdaptiveImage(
                  widget.order.vendorImage,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Rate ${widget.order.vendorName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'How was your experience?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        index < _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 40,
                        color: index < _rating
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFFD1D5DB),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _commentController,
                maxLines: 4,
                decoration: appInputDecoration(
                  hintText: 'Share more details about your experience...',
                  hintStyle: const TextStyle(color: AppTheme.muted),
                  fillColor: const Color(0xFFF9FAFB),
                  borderColor: const Color(0xFFE5E7EB),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (kDebugMode) {
                      debugPrint('RatingModal: Submit Rating Button tapped!');
                    }
                    try {
                      final customer = ref.read(authProvider);
                      if (kDebugMode) {
                        debugPrint('RatingModal: Customer is $customer');
                      }
                      if (customer == null) {
                        if (context.mounted) {
                          Navigator.pop(context); // Close rating modal
                          LoginRequiredSheet.show(
                            context,
                            message: 'You must be logged in to leave a review.',
                          );
                        }
                        return;
                      }

                      // Firebase mode writes reviews under the REAL stallId
                      // (the callable validates order↔stall ownership with
                      // it); mock mode maps onto the seeded demo vendors.
                      final vendorId = ref.read(firebaseEnabledProvider)
                          ? (widget.order.stallId ?? '')
                          : MockDataService.resolveMockVendorId(
                              widget.order.stallId ?? '',
                            );
                      if (kDebugMode) {
                        debugPrint('RatingModal: Resolved vendorId: $vendorId');
                      }

                      final review = VendorReview(
                        id: 'rev-${DateTime.now().millisecondsSinceEpoch}',
                        vendorId: vendorId,
                        customerId: customer.uid,
                        customerName:
                            ref
                                .read(currentProfileProvider)
                                .value
                                ?.displayName ??
                            customer.displayName ??
                            'Customer',
                        rating: _rating.toDouble(),
                        comment: _commentController.text.trim(),
                        date: DateTime.now(),
                        orderId: widget.order.id,
                        reviewType:
                            ReviewType.vendor, // Assuming overall stall rating
                      );

                      // Add review to repository
                      if (kDebugMode) {
                        debugPrint(
                          'RatingModal: Adding review to repository...',
                        );
                      }
                      await ref
                          .read(vendorRepositoryProvider)
                          .addReview(review);
                      if (kDebugMode) {
                        debugPrint('RatingModal: Review added successfully.');
                      }

                      // Invalidate review-related providers to update UI in real-time
                      ref.invalidate(vr.vendorReviewsProvider);
                      ref.invalidate(vr.vendorReviewsFamilyProvider(vendorId));
                      ref.invalidate(vendorProfileProvider(vendorId));

                      // If it is 5 stars, we trigger a notification for the stall holder
                      if (_rating == 5) {
                        ref
                            .read(notificationServiceProvider)
                            .addNotification(
                              AppNotification(
                                id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
                                type: NotificationType.review,
                                target: NotificationTarget.vendor,
                                title: 'New 5-Star Rating!',
                                body:
                                    '${customer.displayName ?? "A customer"} left a 5-star review for your stall!',
                                createdAt: DateTime.now(),
                              ),
                            );
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Thank you for your rating!',
                              style: TextStyle(),
                            ),
                          ),
                        );
                      }
                    } catch (e, stack) {
                      if (kDebugMode) debugPrint('RatingModal Error: $e');
                      if (kDebugMode) debugPrint(stack.toString());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error submitting rating: $e'),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Submit Rating',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
