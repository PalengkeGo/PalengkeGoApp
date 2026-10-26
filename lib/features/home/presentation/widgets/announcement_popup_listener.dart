import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/features/home/application/announcement_provider.dart';
import 'package:palengkego/features/home/presentation/widgets/announcement_popup_dialog.dart';

class AnnouncementPopupListener extends ConsumerWidget {
  const AnnouncementPopupListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(activeAnnouncementsProvider, (_, next) {
      next.whenData((announcements) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final popupContext =
              AppServices.navigatorKey.currentState?.overlay?.context;
          if (popupContext != null) {
            AnnouncementPopupDialog.checkAndShowPending(
              popupContext,
              announcements,
            );
          }
        });
      });
    });
    ref.watch(activeAnnouncementsProvider);
    return child;
  }
}
