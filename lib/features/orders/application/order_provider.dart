import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/features/orders/data/firebase_order_repository.dart';
import 'package:palengkego/features/orders/data/mock_order_repository.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_repository.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';

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

  /// Customer requests a refund on a paid order. Completes on success; throws
  /// a typed [OrderFailure] if the order is not refundable.
  ///
  /// On success the affected vendor receives a "Refund request" notification
  /// (see [NotificationService.onRefundRequested]).
  Future<void> requestRefund(String orderId, {String? reason}) async {
    if (ref.read(authProvider)?.uid == null) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'You must be signed in to request a refund.',
      );
    }
    // Capture the order before the mutation so the vendor-facing
    // notification can reference its vendor name and total even after
    // the list refetches with the flipped paymentStatus.
    final ordersBefore =
        ref.read(orderServiceProvider).value ?? const <MarketOrder>[];
    final orderBefore =
        ordersBefore.where((o) => o.id == orderId).firstOrNull;

    await ref
        .read(orderRepositoryProvider)
        .requestRefund(orderId, reason: reason);
    ref.invalidateSelf();

    ref.read(notificationServiceProvider).onRefundRequested(
          orderId,
          orderBefore?.vendorName ?? 'The stall',
          amount: orderBefore?.total,
          reason: reason,
        );
  }

  /// Vendor/admin resolves a customer's refund request.
  Future<void> processRefundRequest(
    String orderId, {
    required bool approve,
    String? reason,
  }) async {
    await ref
        .read(orderRepositoryProvider)
        .processRefundRequest(orderId, approve: approve, reason: reason);
    ref.invalidateSelf();
  }

  void refresh() {
    ref.invalidateSelf();
  }
}

/// Global OrderService Notifier provider.
final orderServiceProvider =
    AsyncNotifierProvider<OrderService, List<MarketOrder>>(OrderService.new);
