import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_repository.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/order_status_history.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';

/// Firestore-backed [OrderRepository] that routes every MUTATION through the
/// trusted Cloud Functions backend:
///
///   placeOrders       → `placeOrder`       (server-side pricing + stock)
///   updateOrderStatus → `updateOrderStatus` (state machine + audit log)
///   cancelOrder       → `cancelOrder`      (window check + audit log)
///
/// The client never writes prices, stock, or statusHistory directly — it only
/// READS orders/history from Firestore. The functions stamp the real acting
/// uid on every statusHistory entry, so no audit entry can be forged.
class FirebaseOrderRepository implements OrderRepository {
  FirebaseOrderRepository(this._firestore, this._auth, this._functions);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  // ── Place orders (trusted path) ────────────────────────────────────────────

  @override
  Future<List<MarketOrder>> placeOrders({
    required Map<String, (String vendorImage, List<OrderLineItem> items)>
    groupedItems,
    required bool isPickup,
    String customerUid = '',
    String customerName = 'Customer',
    Map<String, String>? vendorNotes,
    String? deliveryAddress,
    bool isPriority = false,
    double priorityFee = 0.0,
    String paymentMethod = 'cod',
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'You must be signed in to place an order.',
      );
    }

    final callable = _functions.httpsCallable('placeOrder');

    // The trusted path needs each vendor's stallId (it recomputes prices and
    // stock server-side). An unresolvable vendor means we cannot safely place
    // that order — fail loudly instead of placing a ghost order.
    final vendorStallIds = <String, String>{};
    for (final vendorName in groupedItems.keys) {
      final stallSnap = await _firestore
          .collection('vendorStalls')
          .where('name', isEqualTo: vendorName)
          .get();
      if (stallSnap.docs.length > 1) {
        // Ambiguous stall name — picking one arbitrarily could send the
        // order (and the customer's money) to the wrong vendor.
        throw OrderFailure(
          OrderFailureType.orderNotFound,
          message:
              'Multiple stalls are named "$vendorName". Please reorder from '
              'the stall page directly.',
        );
      }
      if (stallSnap.docs.isEmpty) {
        throw OrderFailure(
          OrderFailureType.orderNotFound,
          message:
              'The stall "$vendorName" is no longer available. Your order was not placed.',
        );
      }
      vendorStallIds[vendorName] = stallSnap.docs.first.id;
    }

    final created = <MarketOrder>[];
    try {
      await _placeGroupedOrders(
        groupedItems: groupedItems,
        vendorStallIds: vendorStallIds,
        callable: callable,
        isPickup: isPickup,
        isPriority: isPriority,
        customerName: customerName,
        deliveryAddress: deliveryAddress,
        vendorNotes: vendorNotes,
        paymentMethod: paymentMethod,
        created: created,
      );
    } on OrderFailure catch (failure) {
      // Multi-vendor partial-commit guard: if a later vendor's order fails,
      // best-effort cancel the ones already placed (inside the 5-min window)
      // so the customer is never left with half an order. If compensation
      // itself fails, the error says so honestly.
      var compensatedAll = true;
      for (final order in created) {
        try {
          await cancelOrder(
            order.id,
            reason: 'Auto-cancelled: another vendor in this checkout failed.',
          );
        } catch (_) {
          compensatedAll = false;
        }
      }
      throw OrderFailure(
        failure.type,
        message: compensatedAll
            ? '${failure.message} Any orders already placed in this checkout '
                'were cancelled — nothing was charged.'
            : '${failure.message} Some already-placed orders in this checkout '
                'could NOT be auto-cancelled — please cancel them from your '
                'orders screen or contact the stall.',
      );
    }
    return created;
  }

  Future<void> _placeGroupedOrders({
    required Map<String, (String vendorImage, List<OrderLineItem> items)>
        groupedItems,
    required Map<String, String> vendorStallIds,
    required HttpsCallable callable,
    required bool isPickup,
    required bool isPriority,
    required String customerName,
    required String? deliveryAddress,
    required Map<String, String>? vendorNotes,
    required String paymentMethod,
    required List<MarketOrder> created,
  }) async {
    for (final entry in groupedItems.entries) {
      final stallId = vendorStallIds[entry.key]!;
      final lineItems = entry.value.$2;

      final result = await _callTrusted(
        callable,
        {
          'stallId': stallId,
          'items': lineItems
              .map(
                (i) => {
                  'productId': i.productId,
                  'quantity': i.quantity,
                  'unit': i.unit,
                },
              )
              .toList(),
          'fulfillmentMethod': isPickup ? 'pickup' : 'delivery',
          'isPriority': isPickup ? false : isPriority,
          'customerName': customerName,
          'deliveryAddress': isPickup ? null : deliveryAddress,
          'notes': vendorNotes?[entry.key],
          'paymentMethod': paymentMethod,
        },
      );

      final orderId =
          ((result.data as Map<dynamic, dynamic>)['orderId'] as String?) ?? '';
      if (orderId.isEmpty) {
        throw const OrderFailure(
          OrderFailureType.orderNotFound,
          message: 'The order was created but could not be confirmed.',
        );
      }
      final snap = await _orders.doc(orderId).get();
      created.add(_fromFirestore(orderId, snap.data() ?? const {}));
    }
  }

  // ── Queries ─────────────────────────────────────────────────────────────────

  @override
  Future<List<MarketOrder>> getOrdersForCustomer(String customerUid) async {
    final snap = await _orders
        .where('customerUid', isEqualTo: customerUid)
        .orderBy('placedAt', descending: true)
        .get();
    return snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<List<MarketOrder>> getOrdersForVendor(String stallId) async {
    final snap = await _orders
        .where('stallId', isEqualTo: stallId)
        .orderBy('placedAt', descending: true)
        .get();
    return snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList();
  }

  // ── Status update (trusted path) ────────────────────────────────────────────

  @override
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String? changedByUid,
    String? remarks,
    DateTime? estimatedReadyTime,
  }) async {
    await _callTrusted(_functions.httpsCallable('updateOrderStatus'), {
      'orderId': orderId,
      'newStatus': newStatus.name,
      'remarks': ?remarks,
      'estimatedReadyTime': ?estimatedReadyTime?.toIso8601String(),
    });
  }

  // ── Cancel (trusted path) ───────────────────────────────────────────────────

  @override
  Future<void> cancelOrder(
    String orderId, {
    String? reason,
    DateTime? now,
  }) async {
    await _callTrusted(_functions.httpsCallable('cancelOrder'), {
      'orderId': orderId,
      'reason': ?reason,
    });
  }

  // ── History (read-only) ─────────────────────────────────────────────────────

  @override
  Future<List<OrderStatusHistory>> getOrderHistory(String orderId) async {
    final snap = await _orders
        .doc(orderId)
        .collection('statusHistory')
        .orderBy('changedAt')
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return OrderStatusHistory(
        historyId: d.id,
        orderId: orderId,
        previousStatus: data['previousStatus'] != null
            ? OrderStatus.values.firstWhere(
                (s) => s.name == data['previousStatus'],
                orElse: () => OrderStatus.pending,
              )
            : null,
        newStatus: OrderStatus.values.firstWhere(
          (s) => s.name == (data['newStatus'] as String? ?? 'pending'),
          orElse: () => OrderStatus.pending,
        ),
        changedBy: data['changedBy'] as String? ?? '',
        changedAt:
            (data['changedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        remarks: data['remarks'] as String?,
      );
    }).toList();
  }

  // ── Trusted-call plumbing ───────────────────────────────────────────────────

  Future<HttpsCallableResult<dynamic>> _callTrusted(
    HttpsCallable callable,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await callable.call(payload);
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctionsException(e);
    }
  }

  /// Maps HTTPS-callable error codes onto the typed [OrderFailure] contract
  /// the UI already understands.
  OrderFailure _mapFunctionsException(FirebaseFunctionsException e) {
    final code = e.code.replaceFirst('functions/', '');
    switch (code) {
      case 'unauthenticated':
        return const OrderFailure(
          OrderFailureType.unauthenticated,
          message: 'You must be signed in to do that.',
        );
      case 'permission-denied':
        return const OrderFailure(
          OrderFailureType.unauthenticated,
          message: 'You do not have permission to do that.',
        );
      case 'not-found':
        return const OrderFailure(
          OrderFailureType.orderNotFound,
          message: 'A product in your order is no longer available.',
        );
      case 'out-of-range':
        return OrderFailure(
          OrderFailureType.outOfStock,
          message: e.message ?? 'Not enough stock for one of your items.',
        );
      case 'failed-precondition':
        return OrderFailure(
          OrderFailureType.illegalStatusTransition,
          message: e.message ?? 'This action is not allowed right now.',
        );
      case 'already-exists':
        return OrderFailure(
          OrderFailureType.alreadyTerminal,
          message: e.message ?? 'This has already been done.',
        );
      case 'deadline-exceeded':
        return OrderFailure(
          OrderFailureType.cancelWindowExpired,
          message: e.message ?? 'The cancellation window has expired.',
        );
      case 'resource-exhausted':
        return OrderFailure(
          OrderFailureType.rateLimited,
          message: e.message ?? 'Too many requests — please try again shortly.',
        );
      default:
        return OrderFailure(
          OrderFailureType.orderNotFound,
          message: e.message ?? 'Something went wrong. Please try again.',
        );
    }
  }

  // ── Serialization (read-only; clients never write order docs) ──────────────

  MarketOrder _fromFirestore(String id, Map<String, dynamic> data) {
    final items = (data['items'] as List<dynamic>? ?? [])
        .map(
          (i) => OrderLineItem(
            productId: i['productId'] as String? ?? 'dummy',
            productName: i['productName'] as String? ?? '',
            quantity: (i['quantity'] as num?)?.toDouble() ?? 1,
            unitPrice: (i['unitPrice'] as num?)?.toDouble() ?? 0,
            unit: i['unit'] as String? ?? '',
            image: i['image'] as String? ?? '',
          ),
        )
        .toList();

    return MarketOrder(
      id: id,
      vendorName: data['vendorName'] as String? ?? '',
      vendorImage: data['vendorImage'] as String? ?? '',
      customerName: data['customerName'] as String? ?? 'Customer',
      status: OrderStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String? ?? 'pending'),
        orElse: () => OrderStatus.pending,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (s) => s.name == (data['paymentStatus'] as String? ?? 'pending'),
        orElse: () => PaymentStatus.pending,
      ),
      paymentMethod: data['paymentMethod'] as String? ?? 'cod',
      fulfillmentMethod: FulfillmentMethod.values.firstWhere(
        (f) => f.name == (data['fulfillmentMethod'] as String? ?? 'pickup'),
        orElse: () => FulfillmentMethod.pickup,
      ),
      deliveryAddress: data['deliveryAddress'] as String?,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0,
      serviceFee: (data['serviceFee'] as num?)?.toDouble() ?? 0,
      isPriority: data['isPriority'] as bool? ?? false,
      priorityFee: (data['priorityFee'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'] as String?,
      placedAt: (data['placedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estimatedReadyTime: data['estimatedReadyTime'] != null
          ? DateTime.tryParse(data['estimatedReadyTime'] as String)
          : null,
      cancellationReason: data['cancellationReason'] as String?,
      items: items,
    );
  }
}
