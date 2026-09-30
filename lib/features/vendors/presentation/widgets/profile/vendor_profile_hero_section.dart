import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
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
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.8,
              child: AdaptiveImage(source, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(marketSchedulesProvider).value;
    final now = ref.watch(closingClockProvider).value ?? DateTime.now();
    final schedule = schedules?[profile.id];
    final isOpen = schedule == null
        ? profile.isOpen
        : isScheduleOpenNow(schedule, now);
    final minutesToClose = schedule == null
        ? null
        : minutesUntilClosing(schedule, now, isOpen: isOpen);
    return SizedBox(
      height: 208,
      child: Stack(
        children: [
          Container(
            height: 160,
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black12),
                bottom: BorderSide(color: Colors.black12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.25),
                  offset: Offset(0, 4),
                  blurRadius: 4,
                ),
              ],
            ),
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
          Positioned(
            left: 16,
            top: 104,
            child: GestureDetector(
              onTap: () => _showImage(
                context,
                profile.avatarUrl.isNotEmpty ? profile.avatarUrl : profile.imageUrl,
              ),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.1),
                      offset: Offset(0, 4),
                      blurRadius: 6,
                      spreadRadius: -1,
                    ),
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.1),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      spreadRadius: -2,
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
                        size: 40,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? const Color(0xFFDCFCE7)
                        : AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isOpen
                          ? const Color.fromRGBO(22, 163, 74, 0.2)
                          : const Color.fromRGBO(100, 116, 139, 0.2),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isOpen ? 'Open Now' : 'Closed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isOpen ? AppTheme.success : AppTheme.textSecondary,
                      height: 1,
                    ),
                  ),
                ),
                if (minutesToClose != null) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Closes in $minutesToClose min',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF714500)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
