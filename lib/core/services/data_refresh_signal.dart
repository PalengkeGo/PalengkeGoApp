import 'dart:async';

import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A simple counter that increments whenever product/vendor data
/// has changed and downstream providers should refresh.
///
/// Any provider that needs to refresh when product data changes
/// should `ref.watch(dataRefreshSignal)` in its build method.
class DataRefreshSignal extends Notifier<int> {
  DateTime? _lastNotifiedAt;

  @override
  int build() {
    _lastNotifiedAt ??= DateTime.now();
    return 0;
  }

  /// Call this to signal that product/vendor data has changed.
  void notify() {
    _lastNotifiedAt = DateTime.now();
    state++;
  }

  /// Signals a refresh only when at least [maxAge] has elapsed since the
  /// previous notification (or startup). Explicit user refreshes call [notify].
  bool notifyIfStale([Duration maxAge = const Duration(minutes: 5)]) {
    final last = _lastNotifiedAt;
    if (last != null && DateTime.now().difference(last) < maxAge) {
      return false;
    }
    notify();
    return true;
  }
}

final dataRefreshSignal = NotifierProvider<DataRefreshSignal, int>(
  DataRefreshSignal.new,
);

/// Refresh remote data and confirmed email changes when the app resumes.
final backendRefreshProvider = Provider<void>((ref) {
  if (ref.watch(supabaseClientProvider) == null) return;
  DateTime? lastResumeAuthSync;

  final lifecycle = AppLifecycleListener(
    onResume: () async {
      final now = DateTime.now();
      final shouldSyncAuth =
          lastResumeAuthSync == null ||
          now.difference(lastResumeAuthSync!) >= const Duration(seconds: 30);
      if (shouldSyncAuth) {
        lastResumeAuthSync = now;
        if (ref.read(firebaseEnabledProvider)) {
          try {
            await ref.read(firebaseAuthProvider)?.currentUser?.reload();
            if (ref.mounted) await ref.read(authProvider.notifier).reloadUser();
          } catch (_) {
            // A later resume/sign-in retries synchronization when connectivity returns.
          }
        }
        if (ref.mounted && ref.read(authProvider) != null) {
          unawaited(ref.read(orderServiceProvider.notifier).refresh());
        }
      }
      if (ref.mounted) {
        ref
            .read(dataRefreshSignal.notifier)
            .notifyIfStale(const Duration(minutes: 5));
      }
    },
  );
  ref.onDispose(() {
    lifecycle.dispose();
  });
});
