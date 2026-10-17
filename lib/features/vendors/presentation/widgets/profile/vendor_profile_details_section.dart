import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/core/widgets/login_required_sheet.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/messages/application/messaging_provider.dart';
import 'package:palengkego/features/messages/presentation/pages/chat_screen.dart';
import 'package:palengkego/features/vendors/application/vendor_reviews_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_profile.dart';
import 'vendor_reviews_carousel.dart';

class VendorProfileDetailsSection extends ConsumerWidget {
  final VendorProfile profile;

  const VendorProfileDetailsSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Real reviews through the repository (Firebase mode reads the
    // `ratings` collection; mock mode serves the seeded demo set).
    final reviewsAsync = ref.watch(vendorReviewsFamilyProvider(profile.id));

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _inlineMeta(
                    icon: Icons.storefront_outlined,
                    text: profile.stallLocation,
                  ),
                  const SizedBox(width: 16),
                  _inlineMeta(
                    icon: Icons.photo_library_outlined,
                    text: '${profile.category} Section',
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.vendorReviews,
                        arguments: VendorReviewsRouteArgs(vendorId: profile.id),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: Color(0xFFFACC15),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          profile.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (profile.reviewCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${profile.reviewCount})',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryGreen,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (profile.description != null &&
                profile.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                profile.description!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            reviewsAsync.maybeWhen(
              skipLoadingOnReload: true,
              data: (reviews) => reviews.isNotEmpty
                  ? Column(
                      children: [
                        const SizedBox(height: 16),
                        // We need to wrap it in a slightly transformed padding so it bleeds out if we want,
                        // but since we are already inside a Padding(horizontal: 16), we should offset it.
                        Transform.translate(
                          offset: const Offset(-16, 0),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: VendorReviewsCarousel(reviews: reviews),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    )
                  : const SizedBox(height: 24),
              orElse: () => const SizedBox(height: 24),
            ),
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    context,
                    icon: Icons.call_outlined,
                    label: 'Call',
                    onTap: () async {
                      final number = profile.phoneNumber?.replaceAll(
                        RegExp(r'\s+'),
                        '',
                      );
                      if (number != null && number.isNotEmpty) {
                        final uri = Uri.parse('tel:$number');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          if (!context.mounted) return;
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            const SnackBar(
                              content: Text('Could not launch dialer.'),
                            ),
                          );
                        }
                      } else {
                        if (!context.mounted) return;
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          const SnackBar(
                            content: Text('No phone number available.'),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _actionButton(
                    context,
                    key: const Key('vendor_profile_chat_button'),
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chat with Stall Holder',
                    onTap: () async {
                      final user = ref.read(authProvider);
                      if (user == null) {
                        LoginRequiredSheet.show(
                          context,
                          message:
                              'Please sign in to chat with the stall holder.',
                        );
                        return;
                      }

                      try {
                        final conv = await ref
                            .read(messagingActionsProvider)
                            .getOrCreateConversation(
                              customerUid: user.uid,
                              customerName: user.displayName ?? 'Customer',
                              stallId: profile.id,
                              stallName: profile.name,
                              stallAvatar: profile.avatarUrl,
                              inquiryType: 'product',
                            );

                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          PageTransitions.slideFromRight(
                            ChatScreen(
                              conversationId: conv.id,
                              displayName: profile.name,
                              isVendorView: false,
                              inquiryType: conv.inquiryType,
                              relatedOrderId: conv.relatedOrderId,
                            ),
                          ),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          AppServices.showError('Unable to open chat: $e');
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inlineMeta({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF4B5563)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF4B5563),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Key? key,
  }) {
    return GestureDetector(
      key: key,
      onTap:
          onTap ??
          () {
            if (!context.mounted) return;
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text('$label stall holder coming soon!')),
            );
          },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(11, 55, 43, 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
