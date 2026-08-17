import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/features/orders/data/shared_order_store.dart';
import 'package:palengkego/features/recipes/application/recipe_provider.dart';

/// Global singleton for NotificationService.
/// Riverpod v3 does not have ChangeNotifierProvider — widgets that need to
/// react to internal mutations should wrap reads in [ListenableBuilder].
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    recipeRepository: ref.watch(recipeRepositoryProvider),
    orderStore: ref.watch(orderStoreProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
