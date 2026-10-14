import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/home/domain/system_announcement.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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

  static const String prefKeyLastPopupDate = 'last_popup_announcement';

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
    final popup = announcements.where(
      (item) => item.showAsPopup && item.isActive,
    );
    if (popup.isEmpty) return;
    final announcement = popup.first;

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test') ||
        (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));
    if (isTest) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final lastShown = prefs.getString(prefKeyLastPopupDate);
      final popupKey = '${announcement.announcementId}:$today';

      if (lastShown != popupKey && context.mounted) {
        await prefs.setString(prefKeyLastPopupDate, popupKey);
        if (context.mounted) {
          await PriceMonitoringPopupDialog.show(context, announcement);
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

/// Daily in-app preview of an announcement configured as a popup by an admin.
class PriceMonitoringPopupDialog extends StatefulWidget {
  const PriceMonitoringPopupDialog({super.key, required this.announcement});

  final SystemAnnouncement announcement;

  static Future<void> show(
    BuildContext context,
    SystemAnnouncement announcement,
  ) => showDialog<void>(
    context: context,
    builder: (_) => PriceMonitoringPopupDialog(announcement: announcement),
  );

  @override
  State<PriceMonitoringPopupDialog> createState() =>
      _PriceMonitoringPopupDialogState();
}

class _PriceMonitoringPopupDialogState
    extends State<PriceMonitoringPopupDialog> {
  late final PageController _pageController = PageController();
  int _currentPage = 0;

  List<String> get _images {
    final gallery = widget.announcement.popupImageUrls
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);
    if (gallery.isNotEmpty) return gallery;
    final featureImage = widget.announcement.imageUrl;
    return featureImage == null || featureImage.isEmpty
        ? const []
        : [featureImage];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openFacebookPost() async {
    final url = widget.announcement.facebookUrl;
    if (url == null || url.isEmpty) return;
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Facebook post.')),
      );
    }
  }

  Future<void> _showFullImage(String imageUrl) => showDialog<void>(
    context: context,
    builder: (_) => _PriceMonitoringImageViewer(imageUrl: imageUrl),
  );

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final dialogHeight = (screen.height * 0.88).clamp(420.0, 720.0).toDouble();
    final images = _images;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: screen.height - 48,
        ),
        child: SizedBox(
          height: dialogHeight,
          child: DecoratedBox(
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.announcement.title,
                              style: const TextStyle(
                                color: AppTheme.primaryGreen,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.announcement.body,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: images.isEmpty
                        ? const Center(child: Text('No image attached.'))
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: images.length,
                            onPageChanged: (index) =>
                                setState(() => _currentPage = index),
                            itemBuilder: (context, index) => GestureDetector(
                              onTap: () => _showFullImage(images[index]),
                              child: Image.network(
                                images[index],
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Text(
                                    'Could not load this announcement image.',
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (images.length > 1) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_currentPage + 1} / ${images.length}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Swipe to browse · Tap to zoom',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (widget.announcement.facebookUrl?.isNotEmpty == true)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openFacebookPost,
                            icon: const Icon(Icons.open_in_new, size: 17),
                            label: const Text('Facebook post'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryGreen,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      if (widget.announcement.facebookUrl?.isNotEmpty == true)
                        const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Got it'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceMonitoringImageViewer extends StatelessWidget {
  const _PriceMonitoringImageViewer({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: Colors.black,
    child: Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Text(
                  'Could not load this announcement image.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            child: IconButton.filledTonal(
              tooltip: 'Close image',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      ],
    ),
  );
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
