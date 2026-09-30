import 'dart:async';
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

/// The deployed database does not publish market/order changes to Realtime yet.
/// ponytail: foreground polling can lag by 15 seconds and refetches watched data;
/// replace with authenticated, scoped Realtime subscriptions as traffic grows.
final backendRefreshProvider = Provider<void>((ref) {
  if (ref.watch(supabaseClientProvider) == null) return;
  void refresh() {
    if (ref.mounted) ref.read(dataRefreshSignal.notifier).notify();
  }

  final lifecycle = AppLifecycleListener(onResume: refresh);
  final timer = Timer.periodic(const Duration(seconds: 15), (_) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      refresh();
    }
  });
  ref.onDispose(() {
    timer.cancel();
    lifecycle.dispose();
  });
});
