import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/data_refresh_signal.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';
import 'package:palengkego/features/vendors/domain/day_schedule.dart';

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
      stallId: isVendor ? user.uid : 'vendor-001',
      ownerUid: isVendor ? user.uid : 'vendor-001',
      name: isVendor ? (user.displayName ?? 'My Stall') : "Diosa Fruit Stand",
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
          final res = await client
              .from('stall_holders')
              .select()
              .eq('user_id', user.uid)
              .maybeSingle();
          if (res != null && !_userMutated) {
            state = state.copyWith(
              stallId: res['stall_holder_id'] as String? ?? state.stallId,
              name: res['stall_name'] as String? ?? state.name,
              category: res['category'] as String? ?? state.category,
              stallNumber: res['stall_number'] as String? ?? state.stallNumber,
              section: res['section'] as String? ?? state.section,
              location: 'Stall ${res['stall_number'] ?? ''}, Floor ${res['floor_number'] ?? '1'}',
              isOpen: res['is_open'] as bool? ?? state.isOpen,
            );
            return;
          }
        }

        final repo = ref.read(vendorRepositoryProvider);
        final stall = await repo.getVendorStall(initialStall.stallId);
        if (!_userMutated && state.stallId == stall.stallId) {
          // Evaluate schedule against current time on load
          final computedIsOpen = stall.schedule.isEmpty
              ? stall.isOpen
              : _isOpenNow(stall.schedule);
          state = stall.copyWith(isOpen: computedIsOpen);
        }
      } catch (_) {}
    });

    // Re-evaluate every minute so the stall auto-closes at the right time
    _scheduleTimer?.cancel();
    _scheduleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (state.schedule.isNotEmpty) {
        final shouldBeOpen = _isOpenNow(state.schedule);
        if (state.isOpen != shouldBeOpen) {
          state = state.copyWith(isOpen: shouldBeOpen);
          ref.read(dataRefreshSignal.notifier).notify();
        }
      }
    });
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
    final effectiveIsOpen = newSchedule.isNotEmpty
        ? _isOpenNow(newSchedule)
        : (isOpen ?? state.isOpen);
    state = state.copyWith(
      name: name ?? state.name,
      description: description ?? state.description,
      category: category ?? state.category,
      location: location ?? state.location,
      bannerImage: bannerImage == ''
          ? null
          : (bannerImage ?? state.bannerImage),
      avatarImage: avatarImage == ''
          ? null
          : (avatarImage ?? state.avatarImage),
      thumbnailImage: thumbnailImage == ''
          ? null
          : (thumbnailImage ?? state.thumbnailImage),
      isOpen: effectiveIsOpen,
      schedule: newSchedule,
    );
    // Sync to backend/mock so it reflects for customers
    final client = ref.read(supabaseClientProvider);
    if (client != null) {
      try {
        await client.from('stall_holders').update({
          'stall_name': state.name,
          'category': state.category,
          'is_open': state.isOpen,
        }).eq('stall_holder_id', state.stallId);
      } catch (_) {}
    }
    await ref.read(vendorRepositoryProvider).updateVendorStall(state);
    ref.invalidate(vendorProfileProvider);
    ref.read(dataRefreshSignal.notifier).notify();
  }

  Future<void> toggleOpen() async {
    _userMutated = true;
    state = state.copyWith(isOpen: !state.isOpen);
    final client = ref.read(supabaseClientProvider);
    if (client != null) {
      try {
        await client.from('stall_holders').update({
          'is_open': state.isOpen,
        }).eq('stall_holder_id', state.stallId);
      } catch (_) {}
    }
    await ref.read(vendorRepositoryProvider).updateVendorStall(state);
    ref.invalidate(vendorProfileProvider);
    ref.read(dataRefreshSignal.notifier).notify();
  }
}

final vendorStallProvider = NotifierProvider<VendorStallNotifier, VendorStall>(
  VendorStallNotifier.new,
);
