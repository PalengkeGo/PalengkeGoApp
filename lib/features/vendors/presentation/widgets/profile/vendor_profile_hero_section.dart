import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/features/vendors/domain/vendor_profile.dart';
import 'package:palengkego/features/vendors/domain/closing_time.dart';
import 'package:palengkego/features/vendors/presentation/widgets/closing_soon_notice.dart';

class VendorProfileHeroSection extends ConsumerWidget {
  final VendorProfile profile;

  const VendorProfileHeroSection({super.key, required this.profile});

  void _showImage(BuildContext context, String source) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width - 24,
                maxHeight: MediaQuery.sizeOf(context).height - 24,
              ),
              child: AdaptiveImage(source, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleState = ref.watch(marketSchedulesProvider);
    final schedules = scheduleState.value;
    final now = ref.watch(closingClockProvider).value ?? DateTime.now();
    final schedule = schedules == null
        ? null
        : findOperatingSchedule(schedules, profile.id);
    final isLive = ref.watch(supabaseConfiguredProvider);
    // In live mode, never show a stale is_open flag when saved hours are
    // missing or still loading. The schedule table is the availability source.
    final isOpen = schedule == null
        ? (!isLive && profile.isOpen)
        : isScheduleOpenNow(schedule, now);
    final minutesToClose = schedule == null
        ? null
        : minutesUntilClosing(schedule, now, isOpen: isOpen);

    const coverHeight = 220.0;
    const cardTop = 180.0;
    const avatarTop = 138.0;
    const avatarSize = 84.0;

    return SizedBox(
      height: 228,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cover photo
          SizedBox(
            height: coverHeight,
            width: double.infinity,
            child: GestureDetector(
              onTap: () => _showImage(
                context,
                profile.imageUrl.isNotEmpty
                    ? profile.imageUrl
                    : 'assets/images/ncpm-onboarding.jpg',
              ),
              child: AdaptiveImage(
                profile.imageUrl.isNotEmpty
                    ? profile.imageUrl
                    : 'assets/images/ncpm-onboarding.jpg',
                fallbackPath: 'assets/images/ncpm-onboarding.jpg',
                fit: BoxFit.cover,
                placeholder: const AdaptiveImage(
                  'assets/images/ncpm-onboarding.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // White rounded overlapping sheet background
          Positioned(
            top: cardTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.05),
                    offset: Offset(0, -2),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          // Circular avatar overlapping cover photo and white card
          Positioned(
            left: 16,
            top: avatarTop,
            child: GestureDetector(
              onTap: () => _showImage(
                context,
                profile.avatarUrl.isNotEmpty
                    ? profile.avatarUrl
                    : profile.imageUrl,
              ),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.1),
                      offset: Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: AdaptiveImage(
                    profile.avatarUrl.isNotEmpty
                        ? profile.avatarUrl
                        : (profile.imageUrl.isNotEmpty
                            ? profile.imageUrl
                            : 'assets/images/ncpm-onboarding.jpg'),
                    fallbackPath: profile.imageUrl.isNotEmpty
                        ? profile.imageUrl
                        : 'assets/images/ncpm-onboarding.jpg',
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: AppTheme.scaffoldBackground,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 38,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Status pills (Open Now and Closing Soon warning)
          Positioned(
            left: 16 + avatarSize + 12,
            right: 16,
            top: cardTop + 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isOpen
                            ? const Color.fromRGBO(22, 163, 74, 0.25)
                            : const Color.fromRGBO(100, 116, 139, 0.2),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOpen
                                ? const Color(0xFF166534)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isOpen ? 'Open Now' : 'Closed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOpen
                                ? const Color(0xFF166534)
                                : const Color(0xFF6B7280),
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (minutesToClose != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0x40D97706),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        closingWarning(minutesToClose),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45309),
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
