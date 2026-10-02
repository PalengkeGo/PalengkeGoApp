import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/home/domain/system_announcement.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modal dialog for system announcements with support for single or
/// multi-announcement carousel paging and daily first-open trigger.
class AnnouncementPopupDialog extends StatefulWidget {
  final List<SystemAnnouncement> announcements;
  final int initialIndex;

  const AnnouncementPopupDialog({
    super.key,
    required this.announcements,
    this.initialIndex = 0,
  });

  static const String prefKeyLastPopupDate = 'last_announcement_popup_date';

  /// Manually shows the announcement dialog.
  static Future<void> show(
    BuildContext context, {
    required List<SystemAnnouncement> announcements,
    int initialIndex = 0,
  }) {
    if (announcements.isEmpty) return Future.value();
    return showDialog<void>(
      context: context,
      builder: (context) => AnnouncementPopupDialog(
        announcements: announcements,
        initialIndex: initialIndex,
      ),
    );
  }

  /// Checks if the popup has been shown today; if not, marks today and displays it.
  static Future<void> checkAndShowDaily(
    BuildContext context,
    List<SystemAnnouncement> announcements,
  ) async {
    if (announcements.isEmpty) return;

    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test') ||
        (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));
    if (isTest) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final lastShown = prefs.getString(prefKeyLastPopupDate);

      if (lastShown != today && context.mounted) {
        await prefs.setString(prefKeyLastPopupDate, today);
        if (context.mounted) {
          await show(context, announcements: announcements);
        }
      }
    } catch (e) {
      debugPrint('Failed to check daily announcement popup: $e');
    }
  }

  @override
  State<AnnouncementPopupDialog> createState() =>
      _AnnouncementPopupDialogState();
}

class _AnnouncementPopupDialogState extends State<AnnouncementPopupDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.announcements.isEmpty ? 0 : widget.announcements.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.announcements.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasMultiple = widget.announcements.length > 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.announcements.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final announcement = widget.announcements[index];
                  return _AnnouncementContent(
                    announcement: announcement,
                    showCloseButton: true,
                    onClose: () => Navigator.of(context).pop(),
                  );
                },
              ),
            ),
            if (hasMultiple) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.announcements.length,
                    (dotIndex) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      width: _currentIndex == dotIndex ? 22 : 6,
                      decoration: BoxDecoration(
                        color: _currentIndex == dotIndex
                            ? AppTheme.primaryGreen
                            : AppTheme.primaryGreen.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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

class _AnnouncementContent extends StatelessWidget {
  final SystemAnnouncement announcement;
  final bool showCloseButton;
  final VoidCallback onClose;

  const _AnnouncementContent({
    required this.announcement,
    required this.showCloseButton,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: AdaptiveImage(
                announcement.imageUrl ?? 'assets/images/ncpm-onboarding.jpg',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            if (showCloseButton)
              Positioned(
                top: 14,
                right: 14,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ANNOUNCEMENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD97706),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  announcement.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
                    height: 1.25,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  announcement.body,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF475569),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
