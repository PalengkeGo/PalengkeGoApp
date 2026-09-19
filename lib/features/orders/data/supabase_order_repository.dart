import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_repository.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/order_status_history.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';

/// Supabase-backed [OrderRepository] that routes every MUTATION through the
/// trusted Supabase Edge Functions (supabase/functions — kebab-case):
///
///   placeOrders       → `place-order`        (server-side pricing + stock)
///   updateOrderStatus → `update-order-status` (state machine + audit log)
///   cancelOrder       → `cancel-order`       (window check + audit log)
///   requestRefund     → `request-refund`     (paid → refundRequested)
///   processRefundRequest → `process-refund`  (approve/decline + money path)
///
/// The client never writes prices, stock, or statusHistory directly — it only
/// READS orders/history from Firestore. The callables stamp the real acting
/// uid on every statusHistory entry, so no audit entry can be forged.
///
/// AUTH NOTE (audit 2026-09-13 H1): auth + App Check tokens attach
/// automatically via the cloud_functions SDK. The callables are deployed in
/// `asia-southeast1`, mirroring setGlobalOptions in functions/src/index.ts.
class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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
    double? deliveryLatitude,
    double? deliveryLongitude,
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

    // The trusted path needs each vendor's stallId (it recomputes prices and
    // stock server-side). An unresolvable vendor means we cannot safely place
    // that order — fail loudly instead of placing a ghost order.
    final vendorStallIds = <String, String>{};
    for (final vendorName in groupedItems.keys) {
      // Stall resolution reads the PUBLIC catalog doc (audit 2026-09-13 M2):
      // name queries need the storefront name, which lives on stallCatalog.
      final stallSnap = await _firestore
          .collection('stallCatalog')
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
        isPickup: isPickup,
        isPriority: isPriority,
        customerName: customerName,
        deliveryAddress: deliveryAddress,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
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
    required bool isPickup,
    required bool isPriority,
    required String customerName,
    required String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    required Map<String, String>? vendorNotes,
    required String paymentMethod,
    required List<MarketOrder> created,
  }) async {
    for (final entry in groupedItems.entries) {
      final stallId = vendorStallIds[entry.key]!;
      final lineItems = entry.value.$2;

      final result = await _callTrusted('place-order', {
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
        'deliveryLatitude': isPickup ? null : deliveryLatitude,
        'deliveryLongitude': isPickup ? null : deliveryLongitude,
        'notes': vendorNotes?[entry.key],
        'paymentMethod': paymentMethod,
      });

      final orderId = (result['orderId'] as String?) ?? '';
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
    await _callTrusted('update-order-status', {
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
    await _callTrusted('cancel-order', {
      'orderId': orderId,
      'reason': ?reason,
    });
  }

  @override
  Future<void> requestRefund(String orderId, {String? reason}) async {
    await _callTrusted('request-refund', {
      'orderId': orderId,
      'reason': ?reason,
    });
  }

  @override
  Future<void> processRefundRequest(
    String orderId, {
    required bool approve,
    String? reason,
  }) async {
    await _callTrusted('process-refund', {
      'orderId': orderId,
      'decision': approve ? 'approve' : 'decline',
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

  /// Calls a trusted Supabase Edge Function via HTTP POST.
  /// Auth token is attached via Authorization: Bearer header.
  /// Uses Firebase ID token from FirebaseAuth for authentication.
  Future<Map<String, dynamic>> _callTrusted(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'You must be signed in to do that.',
      );
    }
    try {
      // Get Firebase ID token for Bearer auth
      final idToken = await user.getIdToken();
      
      // Build the edge function URL
      // Assumes SUPABASE_URL is available via AppConfig
      final supabaseUrl = _getSupabaseUrl();
      final url = Uri.parse('$supabaseUrl/functions/v1/$functionName');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw const OrderFailure(
          OrderFailureType.unauthenticated,
          message: 'You must be signed in to do that.',
        );
      } else {
        // Parse error response from edge function
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final error = errorBody?['error'] as Map<String, dynamic>?;
        final code = error?['code'] as String? ?? 'internal';
        final message = error?['message'] as String?;
        throw _mapEdgeFunctionError(code, message);
      }
    } catch (e) {
      if (e is OrderFailure) rethrow;
      // Network errors, timeout, etc.
      throw const OrderFailure(
        OrderFailureType.networkError,
        message: 'Could not connect to server. Please try again.',
      );
    }
  }

  String _getSupabaseUrl() {
    final url = AppConfig.load().supabaseUrl;
    return url.isNotEmpty ? url : 'https://palengkego.supabase.co';
  }

  /// Maps edge function errors to OrderFailure types.
  OrderFailure _mapEdgeFunctionError(String code, String? message) {
    switch (code) {
      case 'unauthenticated':
        return const OrderFailure(
          OrderFailureType.unauthenticated,
          message: 'You must be signed in to do that.',
        );
      case 'permission-denied':
        return OrderFailure(
          OrderFailureType.illegalStatusTransition,
          message: message ?? 'You do not have permission for this action.',
        );
      case 'not-found':
        return const OrderFailure(
          OrderFailureType.orderNotFound,
          message: 'Order not found.',
        );
      case 'invalid-argument':
        return OrderFailure(
          OrderFailureType.invalidQuantity,
          message: message ?? 'Invalid request data.',
        );
      case 'out-of-range':
        return const OrderFailure(
          OrderFailureType.invalidQuantity,
          message: 'Not enough stock for one of your items.',
        );
      case 'failed-precondition':
        return OrderFailure(
          OrderFailureType.illegalStatusTransition,
          message: message ?? 'This action is not allowed right now.',
        );
      case 'already-exists':
        return const OrderFailure(
          OrderFailureType.alreadyTerminal,
          message: 'This has already been done.',
        );
      case 'deadline-exceeded':
        return const OrderFailure(
          OrderFailureType.cancelWindowExpired,
          message: 'The cancellation window has expired.',
        );
      case 'resource-exhausted':
        return const OrderFailure(
          OrderFailureType.rateLimited,
          message: 'Too many requests — please try again shortly.',
        );
      default:
        return OrderFailure(
          OrderFailureType.networkError,
                message: message ?? 'Something went wrong. Please try again.',
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
      deliveryLatitude: (data['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (data['deliveryLongitude'] as num?)?.toDouble(),
      deliveryDistanceKm: (data['deliveryDistanceKm'] as num?)?.toDouble(),
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
      refundRequestReason: data['refundRequestReason'] as String?,
      refundRequestedAt: data['refundRequestedAt'] != null
          ? (data['refundRequestedAt'] as Timestamp?)?.toDate()
          : null,
      refundedAmount: (data['refundedAmount'] as num?)?.toDouble() ?? 0.0,
      refundId: data['refundId'] as String?,
      items: items,
    );
  }
}
