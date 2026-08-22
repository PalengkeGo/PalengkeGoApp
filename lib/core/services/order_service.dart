import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';

class OrderService extends AsyncNotifier<List<MarketOrder>> {
  static const cancelWindow = FeeConfig.cancelWindow;

  @override
  Future<List<MarketOrder>> build() async {
    final uid = ref.watch(authProvider)?.uid;
    if (uid == null || uid.isEmpty) return [];
    return ref.watch(orderRepositoryProvider).getOrdersForCustomer(uid);
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) return;

    await ref
        .read(orderRepositoryProvider)
        .updateOrderStatus(orderId, newStatus);
    ref.invalidateSelf();
  }

  /// Cancel a pending order within the cancellation window.
  /// Completes on success; otherwise throws a typed [OrderFailure]
  /// (cancel window expired, already terminal, no longer pending, not found).
  Future<void> cancelOrder(String orderId, {DateTime? now}) async {
    if (ref.read(authProvider)?.uid == null) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'You must be signed in to cancel an order.',
      );
    }

    await ref.read(orderRepositoryProvider).cancelOrder(orderId, now: now);
    ref.invalidateSelf();
  }

  void refresh() {
    ref.invalidateSelf();
  }

}
