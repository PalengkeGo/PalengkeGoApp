import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/services/order_service.dart';
import 'package:palengkego/features/orders/data/firebase_order_repository.dart';
import 'package:palengkego/features/orders/data/mock_order_repository.dart';
import 'package:palengkego/features/orders/domain/order_repository.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final firebaseEnabled = ref.watch(firebaseEnabledProvider);
  if (firebaseEnabled) {
    final firestore = ref.watch(firestoreProvider);
    final auth = ref.watch(firebaseAuthProvider);
    final functions = ref.watch(firebaseFunctionsProvider);
    return FirebaseOrderRepository(firestore, auth, functions);
  }
  return MockOrderRepository();
});

/// Global OrderService Notifier provider.
final orderServiceProvider =
    AsyncNotifierProvider<OrderService, List<MarketOrder>>(OrderService.new);
