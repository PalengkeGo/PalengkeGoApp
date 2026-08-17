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
