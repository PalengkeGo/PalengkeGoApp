import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_repository_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';
import 'package:palengkego/features/vendors/domain/day_schedule.dart';
import 'package:palengkego/core/utils/image_url_resolver.dart';

/// Riverpod Notifier that manages the currently logged-in vendor's stall state.
/// Evaluates the saved schedule against device local time every minute and
/// auto-updates [isOpen] accordingly.
///
/// When Firebase is live: swap the Timer for a Cloud Function that writes
/// `isOpen` to Firestore on a server-side schedule (server-authoritative time).
class VendorStallNotifier extends Notifier<VendorStall> {
  Timer? _scheduleTimer;

  /// Set when the user mutates the stall before the async initial fetch
  /// resolves, so the fetch can never clobber their change.
  bool _userMutated = false;

  @override
  VendorStall build() {
    _userMutated = false;
    final user = ref.watch(authProvider);
    final isVendor = user != null && user.isVendor;
    final initialStall = VendorStall(
      stallId: isVendor
          ? (user.uid == 'stall holder-001' ? 'v1' : user.uid)
          : 'v1',
      ownerUid: isVendor ? user.uid : 'v1',
      name: 'My Stall',
      description:
          'Fresh products directly to your doorstep. Quality and freshness guaranteed!',
      category: 'Fruits',
      location: 'Stall 14, Wet Market Section',
      isOpen: true,
    );

    // Fetch the actual saved state asynchronously so we don't lose images!
    Future.microtask(() async {
      try {
        final client = ref.read(supabaseClientProvider);
        if (client != null && isVendor) {
          var res = await client
              .from('stall_holders')
              .select()
              .or('user_id.eq.${user.uid},stall_holder_id.eq.${user.uid}')
              .maybeSingle();

          if (res != null && !_userMutated) {
            final sNum = res['stall_number'] as String? ?? state.stallNumber;
            final fNum = res['floor_number'] as String? ?? '1';
            final prefix =
                (sNum != null &&
                    (sNum.toLowerCase().contains('stall') ||
                        sNum.toLowerCase().contains('block')))
                ? sNum
                : (sNum != null && sNum.isNotEmpty ? 'Stall $sNum' : '');
            final loc = prefix.isNotEmpty
                ? '$prefix, Floor $fNum'
                : 'Floor $fNum';

            final rawBanner =
                (res['banner_image_url'] as String?)?.isNotEmpty == true
                ? (res['banner_image_url'] as String)
                : ((res['banner_url'] as String?)?.isNotEmpty == true
                      ? (res['banner_url'] as String)
                      : (res['cover_photo'] as String?));
            final rawAvatar =
                (res['avatar_image_url'] as String?)?.isNotEmpty == true
                ? (res['avatar_image_url'] as String)
                : ((res['avatar_url'] as String?)?.isNotEmpty == true
                      ? (res['avatar_url'] as String)
                      : (res['profile_photo'] as String?));
            final rawThumb =
                (res['thumbnail_url'] as String?)?.isNotEmpty == true
                ? (res['thumbnail_url'] as String)
                : ((res['thumbnail_image_url'] as String?)?.isNotEmpty == true
                      ? (res['thumbnail_image_url'] as String)
                      : (res['thumbnailImage'] as String?));

            final banner = (rawBanner != null && rawBanner.isNotEmpty)
                ? (resolveImageUrl(rawBanner, client: client) ?? rawBanner)
                : null;
            final avatar = (rawAvatar != null && rawAvatar.isNotEmpty)
                ? (resolveImageUrl(rawAvatar, client: client) ?? rawAvatar)
                : null;
            final thumb = (rawThumb != null && rawThumb.isNotEmpty)
                ? (resolveImageUrl(rawThumb, client: client) ?? rawThumb)
                : null;

            final scheduleRows = await client
                .from('stall_holder_schedule')
                .select()
                .eq('stall_holder_id', res['stall_holder_id']);
            final remoteSchedule = scheduleRows
                .map(
                  (day) => DaySchedule(
                    name: day['day_of_week'] as String,
                    isOpen: day['is_closed'] != true,
                    openTime: (day['opening_time'] as String? ?? '06:00')
                        .substring(0, 5),
                    closeTime: (day['closing_time'] as String? ?? '18:00')
                        .substring(0, 5),
                  ),
                )
                .toList();
            if (!ref.mounted ||
                _userMutated ||
                ref.read(authProvider)?.uid != user.uid) {
              return;
            }
            state = state.copyWith(
              schedule: remoteSchedule,
              floorNumber: fNum,
              stallId: res['stall_holder_id'] as String? ?? state.stallId,
              name: res['stall_name'] as String? ?? state.name,
              category: res['category'] as String? ?? state.category,
              stallNumber: sNum,
              section: res['section'] as String? ?? state.section,
              location: loc,
              isOpen: res['is_open'] as bool? ?? state.isOpen,
              bannerImage: banner,
              avatarImage: avatar,
              thumbnailImage: thumb,
              description: res['description'] as String? ?? '',
            );
            return;
          }
        }

        if (client != null) return;
        final repo = ref.read(vendorRepositoryProvider);
        final stall = await repo.getVendorStall(initialStall.stallId);
        final effectiveLoadedId =
            (stall.stallId == 'stall holder-001' ||
                stall.stallId == 'vendor-001')
            ? 'v1'
            : stall.stallId;
        final effectiveCurrentId =
            (state.stallId == 'stall holder-001' ||
                state.stallId == 'vendor-001')
            ? 'v1'
            : state.stallId;
        if (!_userMutated &&
            (effectiveCurrentId == effectiveLoadedId ||
                state.stallId == 'v1')) {
          final computedIsOpen = stall.schedule.isEmpty
              ? stall.isOpen
              : _isOpenNow(stall.schedule);
          state = stall.copyWith(
            stallId: effectiveLoadedId,
            isOpen: computedIsOpen,
          );
        }
      } catch (_) {}
    });

    // Re-evaluate every minute so the stall auto-closes at the right time
    _scheduleTimer?.cancel();
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test') ||
        (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));
    if (!isTest && ref.read(supabaseClientProvider) == null) {
      _scheduleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (state.schedule.isNotEmpty) {
          final shouldBeOpen = _isOpenNow(state.schedule);
          if (state.isOpen != shouldBeOpen) {
            state = state.copyWith(isOpen: shouldBeOpen);
            ref.read(dataRefreshSignal.notifier).notify();
          }
        }
      });
    }
    ref.onDispose(() => _scheduleTimer?.cancel());

    return initialStall;
  }

  /// Returns true if the current device time falls within today's DaySchedule window.
  static bool _isOpenNow(List<DaySchedule> schedule) {
    final now = DateTime.now();
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final todayName = weekdays[now.weekday - 1]; // weekday is 1=Mon .. 7=Sun
    final today = schedule.where((d) => d.name == todayName).firstOrNull;
    if (today == null || !today.isOpen) return false;

    final openParts = today.openTime.split(':');
    final closeParts = today.closeTime.split(':');
    if (openParts.length < 2 || closeParts.length < 2) return false;

    final openMinutes = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
    final closeMinutes =
        int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
    final nowMinutes = now.hour * 60 + now.minute;

    return nowMinutes >= openMinutes && nowMinutes < closeMinutes;
  }

  Future<void> updateStall({
    String? name,
    String? description,
    String? category,
    String? location,
    String? bannerImage,
    String? avatarImage,
    String? thumbnailImage,
    bool? isOpen,
    List<DaySchedule>? schedule,
  }) async {
    _userMutated = true;
    final newSchedule = schedule ?? state.schedule;
    // If schedule is provided, re-evaluate isOpen from it
    final effectiveIsOpen =
        isOpen ??
        (schedule != null && newSchedule.isNotEmpty
            ? _isOpenNow(newSchedule)
            : state.isOpen);
    final updated = state.copyWith(
      name: name ?? state.name,
      description: description ?? state.description,
      category: category ?? state.category,
      location: location ?? state.location,
      bannerImage: bannerImage ?? state.bannerImage,
      avatarImage: avatarImage ?? state.avatarImage,
      thumbnailImage: thumbnailImage ?? state.thumbnailImage,
      isOpen: effectiveIsOpen,
      schedule: newSchedule,
    );
    final client = ref.read(supabaseClientProvider);
    if (client != null) {
      final token = await ref
          .read(firebaseAuthProvider)
          .currentUser
          ?.getIdToken();
      if (token == null) throw StateError('Sign in to save your stall.');
      await client.functions.invoke(
        'save-stall',
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'stall_name': updated.name,
          'description': updated.description,
          'category': updated.category,
          'is_open': updated.isOpen,
          'banner_image_url': updated.bannerImage,
          'avatar_image_url': updated.avatarImage,
          'thumbnail_url': updated.thumbnailImage,
          if (schedule != null)
            'schedule': schedule.map((day) => day.toJson()).toList(),
        },
      );
    } else {
      await ref.read(vendorRepositoryProvider).updateVendorStall(updated);
    }
    if (!ref.mounted) return;
    state = updated;
    ref.read(dataRefreshSignal.notifier).notify();
  }

  Future<void> toggleOpen() => updateStall(isOpen: !state.isOpen);
}

final vendorStallProvider = NotifierProvider<VendorStallNotifier, VendorStall>(
  VendorStallNotifier.new,
);
