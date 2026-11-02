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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stall Name
            Text(
              profile.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
                height: 1.15,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            // Meta chips row (mint pills)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _metaChip(
                    icon: Icons.storefront_outlined,
                    text: profile.stallLocation,
                  ),
                  const SizedBox(width: 8),
                  _metaChip(
                    text: '${profile.category} Section',
                  ),
                  const SizedBox(width: 8),
                  _metaRatingChip(context),
                ],
              ),
            ),
            // Tagline / Description
            if (profile.description != null &&
                profile.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                profile.description!,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Call & Chat with Stall Holder buttons row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _primaryCallButton(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _outlineChatButton(context, ref),
                ),
              ],
            ),
            // Customer Reviews carousel if present
            reviewsAsync.maybeWhen(
              skipLoadingOnReload: true,
              data: (reviews) => reviews.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Transform.translate(
                          offset: const Offset(-16, 0),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: VendorReviewsCarousel(reviews: reviews),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip({IconData? icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3EE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: const Color(0xFF2D6A4F)),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E3A2F),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRatingChip(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.vendorReviews,
          arguments: VendorReviewsRouteArgs(vendorId: profile.id),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F3EE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              size: 16,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(width: 4),
            Text(
              profile.rating.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E3A2F),
                height: 1.1,
              ),
            ),
            if (profile.reviewCount > 0) ...[
              const SizedBox(width: 3),
              Text(
                '(${profile.reviewCount})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2D6A4F),
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _primaryCallButton(BuildContext context) {
    return GestureDetector(
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
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(alpha: 0.25),
              offset: const Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call_outlined, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Call',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlineChatButton(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      key: const Key('vendor_profile_chat_button'),
      onTap: () async {
        final user = ref.read(authProvider);
        if (user == null) {
          LoginRequiredSheet.show(
            context,
            message: 'Please sign in to chat with the stall holder.',
          );
          return;
        }

        try {
          final stallAvatar = profile.avatarUrl.trim().isNotEmpty
              ? profile.avatarUrl.trim()
              : profile.imageUrl.trim();
          final conv = await ref
              .read(messagingActionsProvider)
              .getOrCreateConversation(
                customerUid: user.uid,
                customerName: user.displayName ?? 'Customer',
                stallId: profile.id,
                stallName: profile.name,
                stallAvatar: stallAvatar.isNotEmpty ? stallAvatar : null,
                inquiryType: 'product',
              );

          if (!context.mounted) return;
          Navigator.of(context).push(
            PageTransitions.slideFromRight(
              ChatScreen(
                conversationId: conv.id,
                displayName: profile.name,
                isVendorView: false,
                stallId: profile.id,
                avatarUrl: stallAvatar.isNotEmpty
                    ? stallAvatar
                    : conv.stallAvatar,
                inquiryType: conv.inquiryType,
                relatedOrderId: conv.relatedOrderId,
              ),
            ),
          );
        } catch (e) {
          if (context.mounted) {
            AppServices.showError(
              'Unable to open chat. Please try again.',
            );
          }
        }
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primaryGreen, width: 1.5),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 17,
              color: AppTheme.primaryGreen,
            ),
            SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Chat with Stall Holder',
                  maxLines: 1,
                  style: TextStyle(
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
