import 'dart:convert';

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
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed [OrderRepository] that routes every MUTATION through the
/// trusted Supabase Edge Functions (supabase/functions — kebab-case):
///
///   placeOrders       → `place-order`        (server-side pricing + stock)
///   updateOrderStatus → `update-order-status` (state machine + audit log)
///   cancelOrder       → `cancel-order`       (window check + audit log)
///   requestRefund     → `request-refund`     (paid → refundRequested)
///   processRefundRequest → `process-refund`  (approve/decline + money path)
///
/// The client READS orders/history from Supabase. The callables stamp the real
/// acting uid on every statusHistory entry, so no audit entry can be forged.
///
/// AUTH NOTE: Firebase Auth provides the UID; Supabase stores the orders and
/// reads are served directly from Supabase. All mutations go through edge
/// functions authenticated via Firebase ID token.
class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository({required FirebaseAuth auth}) : _auth = auth;

  final FirebaseAuth _auth;

  SupabaseClient get _supabase => Supabase.instance.client;

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

    final vendorStallIds = <String, String>{};
    for (final vendorName in groupedItems.keys) {
      final stallResp = await _supabase
          .from('stall_holders')
          .select('stall_holder_id, stall_name')
          .eq('stall_name', vendorName)
          .limit(1);
      final stallRows = stallResp as List<dynamic>? ?? [];
      if (stallRows.isEmpty) {
        vendorStallIds[vendorName] = vendorName;
      } else {
        vendorStallIds[vendorName] =
            (stallRows.first['stall_holder_id'] as String? ?? vendorName);
      }
    }

    final lineItemsByStall = <String, List<Map<String, dynamic>>>{};
    for (final entry in groupedItems.entries) {
      final stallId = vendorStallIds[entry.key];
      if (stallId == null || stallId.isEmpty) continue;
      final items = entry.value.$2
          .map(
            (item) => {
              'productId': item.productId,
              'productName': item.productName,
              'quantity': item.quantity,
              'unitPrice': item.unitPrice,
              'unit': item.unit,
              'image': item.image,
            },
          )
          .toList();
      lineItemsByStall[stallId] = items;
    }

    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken == null) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'Unable to obtain authentication token.',
      );
    }

    final supabaseUrl = AppConfig.load().supabaseUrl;
    final url = Uri.parse(
      '${supabaseUrl.isNotEmpty ? supabaseUrl : 'https://palengkego.supabase.co'}/functions/v1/place-order',
    );

    final resp = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'customerUid': uid,
            'customerName': customerName,
            'lineItemsByStall': lineItemsByStall,
            'isPickup': isPickup,
            'deliveryAddress': deliveryAddress,
            'deliveryLatitude': deliveryLatitude,
            'deliveryLongitude': deliveryLongitude,
            'isPriority': isPriority,
            'priorityFee': priorityFee,
            'paymentMethod': paymentMethod,
            'vendorNotes': vendorNotes,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>?;
      final msg =
          (body?['error'] as Map?)?['message'] as String? ?? resp.body;
      throw OrderFailure(
        OrderFailureType.networkError,
        message: msg,
      );
    }

    final responseBody = jsonDecode(resp.body) as Map<String, dynamic>;
    final orders = (responseBody['orders'] as List<dynamic>? ?? [])
        .map((o) => MarketOrder.fromJson(o as Map<String, dynamic>))
        .toList();

    return orders;
  }

  // ── Mutations via Edge Functions ──────────────────────────────────────────

  @override
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String? changedByUid,
    String? remarks,
    DateTime? estimatedReadyTime,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'You must be signed in to update order status.',
      );
    }
    final idToken = await user.getIdToken();
    if (idToken == null) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'Unable to obtain authentication token.',
      );
    }
    final supabaseUrl = AppConfig.load().supabaseUrl;
    final url = Uri.parse(
      '${supabaseUrl.isNotEmpty ? supabaseUrl : 'https://palengkego.supabase.co'}/functions/v1/update-order-status',
    );
    final resp = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'orderId': orderId,
            'newStatus': newStatus.name,
            'changedByUid': changedByUid,
            'remarks': remarks,
            'estimatedReadyTime': estimatedReadyTime?.toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      _throwFromErrorResponse(resp);
    }
  }

  @override
  Future<void> cancelOrder(
    String orderId, {
    String? reason,
    DateTime? now,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'You must be signed in to cancel an order.',
      );
    }
    final idToken = await user.getIdToken();
    if (idToken == null) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'Unable to obtain authentication token.',
      );
    }
    final supabaseUrl = AppConfig.load().supabaseUrl;
    final url = Uri.parse(
      '${supabaseUrl.isNotEmpty ? supabaseUrl : 'https://palengkego.supabase.co'}/functions/v1/cancel-order',
    );
    final resp = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'orderId': orderId,
            'reason': reason,
            'now': now?.toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      _throwFromErrorResponse(resp);
    }
  }

  @override
  Future<void> requestRefund(
    String orderId, {
    String? reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'You must be signed in to request a refund.',
      );
    }
    final idToken = await user.getIdToken();
    if (idToken == null) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'Unable to obtain authentication token.',
      );
    }
    final supabaseUrl = AppConfig.load().supabaseUrl;
    final url = Uri.parse(
      '${supabaseUrl.isNotEmpty ? supabaseUrl : 'https://palengkego.supabase.co'}/functions/v1/request-refund',
    );
    final resp = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'orderId': orderId,
            'reason': reason,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      _throwFromErrorResponse(resp);
    }
  }

  @override
  Future<void> processRefundRequest(
    String orderId, {
    required bool approve,
    String? reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'You must be signed in to process a refund.',
      );
    }
    final idToken = await user.getIdToken();
    if (idToken == null) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'Unable to obtain authentication token.',
      );
    }
    final supabaseUrl = AppConfig.load().supabaseUrl;
    final url = Uri.parse(
      '${supabaseUrl.isNotEmpty ? supabaseUrl : 'https://palengkego.supabase.co'}/functions/v1/process-refund',
    );
    final resp = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'orderId': orderId,
            'approve': approve,
            'reason': reason,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      _throwFromErrorResponse(resp);
    }
  }

  @override
  Future<List<MarketOrder>> getOrdersForCustomer(String customerUid) async {
    final resp = await _supabase
        .from('orders')
        .select('*, items:order_items(*)')
        .eq('customer_id', customerUid)
        .order('created_at', ascending: false);
    final data = resp as List<dynamic>? ?? [];
    return data.map((d) => _fromSupabase(d as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<MarketOrder>> getOrdersForVendor(String stallId) async {
    final resp = await _supabase
        .from('orders')
        .select('*, items:order_items(*)')
        .eq('stall_holder_id', stallId)
        .order('created_at', ascending: false);
    final data = resp as List<dynamic>? ?? [];
    return data.map((d) => _fromSupabase(d as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<OrderStatusHistory>> getOrderHistory(String orderId) async {
    final resp = await _supabase
        .from('order_status_history')
        .select('*')
        .eq('order_id', orderId)
        .order('changed_at', ascending: true);
    final data = resp as List<dynamic>? ?? [];
    return data.map((d) {
      final map = d as Map<String, dynamic>;
      return OrderStatusHistory(
        historyId: map['history_id'] as String? ?? '',
        orderId: map['order_id'] as String? ?? '',
        previousStatus: map['previous_status'] != null
            ? OrderStatus.values.firstWhere(
                (s) => s.name == map['previous_status'],
                orElse: () => OrderStatus.pending,
              )
            : null,
        newStatus: OrderStatus.values.firstWhere(
          (s) => s.name == (map['new_status'] as String? ?? 'pending'),
          orElse: () => OrderStatus.pending,
        ),
        changedBy: map['changed_by'] as String? ?? '',
        changedAt: map['changed_at'] != null
            ? DateTime.tryParse(map['changed_at'] as String) ?? DateTime.now()
            : DateTime.now(),
        remarks: map['remarks'] as String?,
      );
    }).toList();
  }

  void _throwFromErrorResponse(http.Response resp) {
    final body = jsonDecode(resp.body) as Map<String, dynamic>?;
    final code = (body?['error'] as Map?)?['code'] as String? ?? '';
    final message = (body?['error'] as Map?)?['message'] as String? ?? resp.body;
    switch (code) {
      case 'not-found':
        throw OrderFailure(OrderFailureType.orderNotFound, message: message);
      case 'illegal-status':
        throw OrderFailure(OrderFailureType.illegalStatusTransition, message: message);
      case 'already-terminal':
        throw OrderFailure(OrderFailureType.alreadyTerminal, message: message);
      case 'window-expired':
        throw OrderFailure(OrderFailureType.cancelWindowExpired, message: message);
      case 'out-of-stock':
        throw OrderFailure(OrderFailureType.outOfStock, message: message);
      case 'invalid-quantity':
        throw OrderFailure(OrderFailureType.invalidQuantity, message: message);
      case 'unauthenticated':
        throw OrderFailure(OrderFailureType.unauthenticated, message: message);
      case 'already-exists':
        throw OrderFailure(OrderFailureType.alreadyTerminal, message: message);
      case 'deadline-exceeded':
        throw OrderFailure(OrderFailureType.cancelWindowExpired, message: message);
      case 'resource-exhausted':
        throw OrderFailure(OrderFailureType.rateLimited, message: message);
      default:
        throw OrderFailure(OrderFailureType.networkError, message: message);
    }
  }

  MarketOrder _fromSupabase(Map<String, dynamic> data) {
    final items = (data['items'] as List<dynamic>? ?? [])
        .map(
          (i) => OrderLineItem(
            productId: i['product_id'] as String? ?? 'dummy',
            productName: i['product_name'] as String? ?? '',
            quantity: (i['quantity'] as num?)?.toDouble() ?? 1,
            unitPrice: (i['unit_price'] as num?)?.toDouble() ?? 0,
            unit: i['unit'] as String? ?? '',
            image: i['image'] as String? ?? '',
          ),
        )
        .toList();
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }
    return MarketOrder(
      id: data['id'] as String? ?? '',
      vendorName: data['vendor_name'] as String? ?? '',
      vendorImage: data['vendor_image'] as String? ?? '',
      customerName: data['customer_name'] as String? ?? 'Customer',
      status: OrderStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String? ?? 'pending'),
        orElse: () => OrderStatus.pending,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (s) => s.name == (data['payment_status'] as String? ?? 'pending'),
        orElse: () => PaymentStatus.pending,
      ),
      paymentMethod: data['payment_method'] as String? ?? 'cod',
      fulfillmentMethod: FulfillmentMethod.values.firstWhere(
        (f) => f.name == (data['fulfillment_method'] as String? ?? 'pickup'),
        orElse: () => FulfillmentMethod.pickup,
      ),
      deliveryAddress: data['delivery_address'] as String?,
      deliveryLatitude: (data['delivery_latitude'] as num?)?.toDouble(),
      deliveryLongitude: (data['delivery_longitude'] as num?)?.toDouble(),
      deliveryDistanceKm: (data['delivery_distance_km'] as num?)?.toDouble(),
      deliveryFee: (data['delivery_fee'] as num?)?.toDouble() ?? 0,
      serviceFee: (data['service_fee'] as num?)?.toDouble() ?? 0,
      isPriority: data['is_priority'] as bool? ?? false,
      priorityFee: (data['priority_fee'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'] as String?,
      placedAt: parseDate(data['placed_at']),
      estimatedReadyTime: parseDate(data['estimated_ready_time']),
      cancellationReason: data['cancellation_reason'] as String?,
      refundRequestReason: data['refund_request_reason'] as String?,
      refundRequestedAt: parseDate(data['refund_requested_at']),
      refundedAmount: (data['refunded_amount'] as num?)?.toDouble() ?? 0.0,
      refundId: data['refund_id'] as String?,
      items: items,
    );
  }
}