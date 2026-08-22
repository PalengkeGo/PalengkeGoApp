import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/navigation/app_router.dart';
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
    final reviewsAsync =
        ref.watch(vendorReviewsFamilyProvider(profile.id));

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
                          '${profile.rating}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111827),
                          ),
                        ),
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
                    ),
                  ),
                ],
              ),
            ),
            reviewsAsync.maybeWhen(
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
                    icon: Icons.message_outlined,
                    label: 'Message',
                    onTap: () async {
                      final number = profile.phoneNumber?.replaceAll(
                        RegExp(r'\s+'),
                        '',
                      );
                      if (number != null && number.isNotEmpty) {
                        final uri = Uri.parse('sms:$number');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          if (!context.mounted) return;
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            const SnackBar(
                              content: Text('Could not launch SMS app.'),
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
  }) {
    return GestureDetector(
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
        decoration: BoxDecoration(
          color: const Color.fromRGBO(11, 55, 43, 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
