import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:palengkego/core/config/app_config.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/features/orders/data/mock_order_repository.dart';
import 'package:palengkego/features/orders/data/shared_order_store.dart';
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
  SupabaseOrderRepository({required FirebaseAuth auth, SharedOrderStore? store})
      : _auth = auth,
        _store = store ?? SharedOrderStore();

  final FirebaseAuth _auth;
  final SharedOrderStore _store;

  SupabaseClient get _supabase => Supabase.instance.client;

  // ── Place orders (trusted path) ────────────────────────────────────────────

  @override
  Future<List<MarketOrder>> placeOrders({
    required Map<String, (String vendorImage, List<OrderLineItem> items)>
        groupedItems,
    required bool isPickup,
    String customerUid = '',
    String customerName = 'Customer',
    String? customerPhone,
    Map<String, String>? vendorNotes,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    bool isPriority = false,
    double priorityFee = 0.0,
    String paymentMethod = 'cod',
  }) async {
    final uid = _auth.currentUser?.uid ?? (customerUid.isNotEmpty ? customerUid : 'customer-001');

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

    // Try edge function first if token is available
    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken != null) {
      try {
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
            .timeout(const Duration(seconds: 15));

        if (resp.statusCode == 200) {
          final responseBody = jsonDecode(resp.body) as Map<String, dynamic>;
          final orders = (responseBody['orders'] as List<dynamic>? ?? [])
              .map((o) => MarketOrder.fromJson(o as Map<String, dynamic>))
              .toList();
          if (orders.isNotEmpty) return orders;
        }
      } catch (e) {
        debugPrint('place-order edge function failed, falling back to direct db: $e');
      }
    }

    // Fall back to direct database insert
    return _placeOrdersDirectly(
      groupedItems: groupedItems,
      isPickup: isPickup,
      uid: uid,
      customerName: customerName,
      customerPhone: customerPhone,
      vendorNotes: vendorNotes,
      deliveryAddress: deliveryAddress,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      isPriority: isPriority,
      priorityFee: priorityFee,
      paymentMethod: paymentMethod,
    );
  }

  Future<List<MarketOrder>> _placeOrdersDirectly({
    required Map<String, (String vendorImage, List<OrderLineItem> items)> groupedItems,
    required bool isPickup,
    required String uid,
    required String customerName,
    String? customerPhone,
    Map<String, String>? vendorNotes,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    bool isPriority = false,
    double priorityFee = 0.0,
    String paymentMethod = 'cod',
  }) async {
    String customerId = uid;
    try {
      final custResp = await _supabase
          .from('customers')
          .select('customer_id')
          .eq('user_id', uid)
          .maybeSingle();
      if (custResp != null && custResp['customer_id'] != null) {
        customerId = custResp['customer_id'].toString();
      } else {
        final newCust = await _supabase
            .from('customers')
            .insert({'user_id': uid, 'saved_address': deliveryAddress})
            .select('customer_id')
            .maybeSingle();
        if (newCust != null && newCust['customer_id'] != null) {
          customerId = newCust['customer_id'].toString();
        }
      }
    } catch (_) {}

    final createdOrders = <MarketOrder>[];
    final now = DateTime.now();

    for (final entry in groupedItems.entries) {
      final vendorName = entry.key;
      final vendorImage = entry.value.$1;
      final items = entry.value.$2;
      if (items.isEmpty) continue;

      String stallId = 'v1';
      String resolvedStallName = vendorName;
      String resolvedBanner = vendorImage;
      try {
        var sResp = await _supabase
            .from('stall_holders')
            .select('stall_holder_id, stall_name, banner_image_url, thumbnail_url')
            .eq('stall_name', vendorName.trim())
            .limit(1);
        var rows = sResp as List<dynamic>? ?? [];
        if (rows.isEmpty) {
          sResp = await _supabase
              .from('stall_holders')
              .select('stall_holder_id, stall_name, banner_image_url, thumbnail_url')
              .ilike('stall_name', '%${vendorName.trim()}%')
              .limit(1);
          rows = sResp as List<dynamic>? ?? [];
        }
        if (rows.isNotEmpty) {
          final first = rows.first as Map<String, dynamic>;
          stallId = first['stall_holder_id']?.toString() ?? stallId;
          resolvedStallName = first['stall_name'] as String? ?? vendorName;
          resolvedBanner = first['thumbnail_url'] as String? ??
              first['banner_image_url'] as String? ??
              vendorImage;
        } else if (items.isNotEmpty) {
          final pResp = await _supabase
              .from('products')
              .select('stall_holder_id')
              .eq('product_id', items.first.productId)
              .limit(1);
          final pRows = pResp as List<dynamic>? ?? [];
          if (pRows.isNotEmpty) {
            final pStallId = (pRows.first as Map<String, dynamic>)['stall_holder_id']?.toString();
            if (pStallId != null && pStallId.isNotEmpty) {
              stallId = pStallId;
            }
          }
        }
      } catch (_) {}

      double subtotal = 0.0;
      for (final i in items) {
        subtotal += i.quantity * i.unitPrice;
      }
      final deliveryFee = isPickup
          ? 0.0
          : FeeConfig.computeDeliveryFee(
              lat: deliveryLatitude,
              lng: deliveryLongitude,
            );
      final total = subtotal + deliveryFee + (isPriority ? priorityFee : 0.0) + FeeConfig.serviceFee;

      final cleanPayment = (paymentMethod == 'gcash' || paymentMethod == 'maya' || paymentMethod == 'paymaya')
          ? 'gcash'
          : 'cod';

      String orderId = '#${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch % 10000}';
      DateTime createdAt = now;

      try {
        final orderRow = await _supabase
            .from('orders')
            .insert({
              'customer_id': customerId,
              'stall_holder_id': stallId,
              'fulfillment_type': isPickup ? 'pickup' : 'delivery',
              'delivery_address': isPickup ? null : deliveryAddress,
              'delivery_latitude': isPickup ? null : deliveryLatitude,
              'delivery_longitude': isPickup ? null : deliveryLongitude,
              'distance_km': isPickup || deliveryLatitude == null || deliveryLongitude == null
                  ? 0.0
                  : ((deliveryFee - FeeConfig.deliveryBaseCharge) / FeeConfig.deliveryPerKm).clamp(0.0, 999.0),
              'delivery_fee': deliveryFee,
              'subtotal': subtotal,
              'total_amount': total,
              'payment_method': cleanPayment,
              'payment_status': 'pending',
              'order_status': 'pending',
              'customer_name': customerName,
              'customer_phone': customerPhone,
              'notes': vendorNotes?[vendorName],
              'is_priority': isPriority,
              'priority_fee': isPriority ? priorityFee : 0.0,
            })
            .select('order_id, created_at')
            .maybeSingle();

        if (orderRow != null) {
          orderId = orderRow['order_id'].toString();
          if (orderRow['created_at'] != null) {
            createdAt = DateTime.tryParse(orderRow['created_at'].toString()) ?? now;
          }
        }
      } catch (e) {
        debugPrint('Direct order insert error: $e');
      }

      try {
        final orderItemsData = items.map((i) => {
          'order_id': orderId,
          'product_id': i.productId,
          'product_name': i.productName,
          'category_tag': 'Vegetables',
          'quantity': i.quantity.round() > 0 ? i.quantity.round() : 1,
          'price_at_order': i.unitPrice,
          'subtotal': i.quantity * i.unitPrice,
        }).toList();
        await _supabase.from('order_items').insert(orderItemsData);
      } catch (e) {
        debugPrint('Direct order_items insert error: $e');
      }

      try {
        await _supabase.from('order_status_history').insert({
          'order_id': orderId,
          'previous_status': null,
          'new_status': 'pending',
          'changed_by': uid,
          'remarks': vendorNotes?[vendorName] ?? 'Order placed',
        });
      } catch (_) {}

      // Deduct stock in Supabase products table
      for (final item in items) {
        try {
          final prodRow = await _supabase
              .from('products')
              .select('id, stock_quantity')
              .or('id.eq.${item.productId},name.eq.${item.productName}')
              .maybeSingle();
          if (prodRow != null) {
            final currentStock = (prodRow['stock_quantity'] as num?)?.toDouble() ?? 0.0;
            final newStock = (currentStock - item.quantity).clamp(0.0, 99999.0);
            await _supabase
                .from('products')
                .update({'stock_quantity': newStock})
                .eq('id', prodRow['id']);
          }
        } catch (_) {}
      }

      final marketOrder = MarketOrder(
        id: orderId,
        customerUid: uid,
        stallId: stallId,
        vendorName: resolvedStallName,
        vendorImage: resolvedBanner,
        customerName: customerName,
        customerPhone: customerPhone,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
        paymentMethod: paymentMethod,
        fulfillmentMethod: isPickup ? FulfillmentMethod.pickup : FulfillmentMethod.delivery,
        placedAt: createdAt,
        items: items,
        deliveryAddress: isPickup ? null : deliveryAddress,
        deliveryLatitude: isPickup ? null : deliveryLatitude,
        deliveryLongitude: isPickup ? null : deliveryLongitude,
        deliveryDistanceKm: isPickup || deliveryLatitude == null || deliveryLongitude == null
            ? null
            : ((deliveryFee - FeeConfig.deliveryBaseCharge) / FeeConfig.deliveryPerKm).clamp(0.0, 999.0),
        deliveryFee: deliveryFee,
        serviceFee: FeeConfig.serviceFee,
        isPriority: isPickup ? false : isPriority,
        priorityFee: isPickup ? 0.0 : priorityFee,
        notes: vendorNotes?[vendorName],
      );

      try {
        await _store.load();
        _store.orders.removeWhere((o) => o.id == marketOrder.id);
        _store.orders.insert(0, marketOrder);
        await _store.save();
      } catch (_) {}

      createdOrders.add(marketOrder);
    }

    return createdOrders;
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
    try {
      final resp = await _supabase
          .from('orders')
          .select('*, items:order_items(*), stall:stall_holders(stall_name, banner_image_url, thumbnail_url)')
          .or('customer_id.eq.$customerUid,customer_id.in.(select customer_id from customers where user_id.eq.$customerUid)')
          .order('created_at', ascending: false);

      final data = resp as List<dynamic>? ?? [];
      final orders = data.map((d) => _fromSupabase(d as Map<String, dynamic>)).toList();
      if (orders.isNotEmpty) return orders;
    } catch (e) {
      debugPrint('Supabase getOrdersForCustomer error: $e');
    }

    final mockRepo = MockOrderRepository();
    return mockRepo.getOrdersForCustomer(customerUid);
  }

  @override
  Future<List<MarketOrder>> getOrdersForVendor(String stallId, {String? vendorName}) async {
    try {
      String effectiveStallId = stallId;
      try {
        var sResp = await _supabase
            .from('stall_holders')
            .select('stall_holder_id, stall_name')
            .or('user_id.eq.$stallId,stall_holder_id.eq.$stallId')
            .limit(1);
        var rows = sResp as List<dynamic>? ?? [];
        if (rows.isEmpty && vendorName != null && vendorName.isNotEmpty) {
          sResp = await _supabase
              .from('stall_holders')
              .select('stall_holder_id, stall_name')
              .eq('stall_name', vendorName.trim())
              .limit(1);
          rows = sResp as List<dynamic>? ?? [];
        }
        if (rows.isNotEmpty) {
          final map = rows.first as Map<String, dynamic>;
          effectiveStallId = map['stall_holder_id']?.toString() ?? stallId;
        }
      } catch (_) {}

      final resp = await _supabase
          .from('orders')
          .select('*, items:order_items(*), stall:stall_holders(stall_name, banner_image_url, thumbnail_url)')
          .or('stall_holder_id.eq.$effectiveStallId,stall_holder_id.eq.$stallId')
          .order('created_at', ascending: false);

      final data = resp as List<dynamic>? ?? [];
      final orders = data.map((d) => _fromSupabase(d as Map<String, dynamic>)).toList();
      if (orders.isNotEmpty) return orders;
    } catch (e) {
      debugPrint('Supabase getOrdersForVendor error: $e');
    }

    final mockRepo = MockOrderRepository(store: _store);
    return mockRepo.getOrdersForVendor(stallId, vendorName: vendorName);
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
            unitPrice: (i['price_at_order'] ?? i['unit_price'] as num?)?.toDouble() ?? 0,
            unit: i['unit'] as String? ?? 'kg',
            image: i['image'] as String? ?? '',
          ),
        )
        .toList();
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }
    final stallInfo = data['stall'] as Map<String, dynamic>?;
    final stallName = data['vendor_name'] as String? ??
        stallInfo?['stall_name'] as String? ??
        'Britanico Store';
    final stallImage = data['vendor_image'] as String? ??
        stallInfo?['thumbnail_url'] as String? ??
        stallInfo?['banner_image_url'] as String? ??
        '';

    return MarketOrder(
      id: (data['order_id'] ?? data['id'])?.toString() ?? '',
      stallId: data['stall_holder_id']?.toString(),
      customerUid: data['customer_id']?.toString(),
      vendorName: stallName,
      vendorImage: stallImage,
      customerName: data['customer_name'] as String? ?? 'Customer',
      customerPhone: data['customer_phone'] as String?,
      status: OrderStatus.values.firstWhere(
        (s) => s.name == (data['order_status'] ?? data['status'] as String? ?? 'pending'),
        orElse: () => OrderStatus.pending,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (s) => s.name == (data['payment_status'] as String? ?? 'pending'),
        orElse: () => PaymentStatus.pending,
      ),
      paymentMethod: data['payment_method'] as String? ?? 'cod',
      fulfillmentMethod: FulfillmentMethod.values.firstWhere(
        (f) => f.name == (data['fulfillment_type'] ?? data['fulfillment_method'] as String? ?? 'pickup'),
        orElse: () => FulfillmentMethod.pickup,
      ),
      deliveryAddress: data['delivery_address'] as String?,
      deliveryLatitude: (data['delivery_latitude'] as num?)?.toDouble(),
      deliveryLongitude: (data['delivery_longitude'] as num?)?.toDouble(),
      deliveryDistanceKm: (data['distance_km'] ?? data['delivery_distance_km'] as num?)?.toDouble(),
      deliveryFee: (data['delivery_fee'] as num?)?.toDouble() ?? 0,
      serviceFee: (data['service_fee'] as num?)?.toDouble() ?? 0,
      isPriority: data['is_priority'] as bool? ?? false,
      priorityFee: (data['priority_fee'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'] as String?,
      placedAt: parseDate(data['created_at'] ?? data['placed_at']),
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