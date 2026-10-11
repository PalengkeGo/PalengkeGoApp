import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A simple counter that increments whenever product/vendor data
/// has changed and downstream providers should refresh.
///
/// Any provider that needs to refresh when product data changes
/// should `ref.watch(dataRefreshSignal)` in its build method.
class DataRefreshSignal extends Notifier<int> {
  @override
  int build() => 0;

  /// Call this to signal that product/vendor data has changed.
  void notify() => state++;
}

final dataRefreshSignal = NotifierProvider<DataRefreshSignal, int>(
  DataRefreshSignal.new,
);

/// Refresh remote data and confirmed email changes when the app resumes.
final backendRefreshProvider = Provider<void>((ref) {
  if (ref.watch(supabaseClientProvider) == null) return;
  void refresh() {
    if (ref.mounted) ref.read(dataRefreshSignal.notifier).notify();
  }

  final lifecycle = AppLifecycleListener(
    onResume: () async {
      if (ref.read(firebaseEnabledProvider)) {
        try {
          await ref.read(firebaseAuthProvider).currentUser?.reload();
          if (ref.mounted) await ref.read(authProvider.notifier).reloadUser();
        } catch (_) {
          // A later resume/sign-in retries synchronization when connectivity returns.
        }
      }
      refresh();
    },
  );
  ref.onDispose(() {
    lifecycle.dispose();
  });
});
