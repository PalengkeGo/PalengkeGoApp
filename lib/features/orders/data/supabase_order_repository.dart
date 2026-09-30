import 'package:firebase_auth/firebase_auth.dart';
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

/// Remote failures must never be replaced with successful local-only orders.
class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository({
    FirebaseAuth? auth,
    SupabaseClient? client,
    SharedOrderStore? store,
  }) : _auth = auth,
       _client = client;

  final FirebaseAuth? _auth;
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> body,
  ) async {
    final token = await _auth?.currentUser?.getIdToken();
    if (token == null) {
      throw const OrderFailure(
        OrderFailureType.unauthenticated,
        message: 'Sign in to manage orders.',
      );
    }
    try {
      final response = await _supabase.functions.invoke(
        name,
        body: body,
        headers: {'Authorization': 'Bearer $token'},
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      final error = e.details is Map ? (e.details as Map)['error'] : null;
      final code = error is Map ? error['code'] : null;
      final message = error is Map ? error['message']?.toString() : null;
      throw OrderFailure(
        switch (code) {
          'deadline-exceeded' => OrderFailureType.cancelWindowExpired,
          'unauthenticated' => OrderFailureType.unauthenticated,
          'resource-exhausted' => OrderFailureType.rateLimited,
          'not-found' => OrderFailureType.orderNotFound,
          _ => OrderFailureType.networkError,
        },
        message: message == null
            ? 'Order action failed (HTTP ${e.status}). Please try again.'
            : '$message (HTTP ${e.status})',
      );
    }
  }

  static String _appStatus(dynamic status) => switch (status) {
    'delivered' => 'completed',
    'out_for_delivery' => 'outForDelivery',
    _ => status?.toString() ?? 'pending',
  };

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
    final productIds = groupedItems.values
        .expand((group) => group.$2)
        .map((item) => item.productId)
        .toSet()
        .toList();
    if (productIds.isEmpty) throw StateError('Your cart is empty.');
    final products = await _supabase
        .from('products')
        .select('product_id, stall_holder_id')
        .inFilter('product_id', productIds);
    final stalls = {
      for (final product in products)
        product['product_id']: product['stall_holder_id'] as String,
    };
    final groups = <String, List<Map<String, dynamic>>>{};
    final notes = <String, String>{};
    for (final entry in groupedItems.entries) {
      for (final item in entry.value.$2) {
        final stallId = stalls[item.productId];
        if (stallId == null) {
          throw StateError('${item.productName} is no longer available.');
        }
        groups.putIfAbsent(stallId, () => []).add({
          'productId': item.productId,
          'quantity': item.quantity,
        });
        if (vendorNotes?[entry.key] != null) {
          notes[stallId] = vendorNotes![entry.key]!;
        }
      }
    }
    final result = await _invoke('place-order', {
      'lineItemsByStall': groups,
      'isPickup': isPickup,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'isPriority': isPriority,
      'paymentMethod': paymentMethod,
      'vendorNotes': notes,
    });
    final rows = (result['orders'] as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) throw StateError('No orders were created.');
    return rows.map(_fromSupabase).toList();
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String? changedByUid,
    String? remarks,
    DateTime? estimatedReadyTime,
  }) async {
    await _invoke('update-order-status', {
      'orderId': orderId,
      'newStatus': newStatus.name,
      'remarks': remarks,
      'estimatedReadyTime': estimatedReadyTime?.toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> cancelOrder(
    String orderId, {
    String? reason,
    DateTime? now,
  }) async {
    await _invoke('cancel-order', {'orderId': orderId, 'reason': reason});
  }

  @override
  Future<void> requestRefund(String orderId, {String? reason}) async {
    await _invoke('request-refund', {'orderId': orderId, 'reason': reason});
  }

  @override
  Future<void> processRefundRequest(
    String orderId, {
    required bool approve,
    String? reason,
  }) async {
    await _invoke('process-refund', {
      'orderId': orderId,
      'approve': approve,
      'reason': reason,
    });
  }

  @override
  Future<List<MarketOrder>> getOrdersForCustomer(String customerUid) async {
    final response = await _invoke('read-orders', {'vendor': false});
    return (response['orders'] as List)
        .map((row) => _fromSupabase(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<List<MarketOrder>> getOrdersForVendor(
    String stallId, {
    String? vendorName,
  }) async {
    final response = await _invoke('read-orders', {'vendor': true});
    return (response['orders'] as List)
        .map((row) => _fromSupabase(Map<String, dynamic>.from(row as Map)))
        .toList();
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
                (s) => s.name == _appStatus(map['previous_status']),
                orElse: () => OrderStatus.pending,
              )
            : null,
        newStatus: OrderStatus.values.firstWhere(
          (s) => s.name == _appStatus(map['new_status']),
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

  MarketOrder _fromSupabase(Map<String, dynamic> data) {
    final items = (data['items'] as List<dynamic>? ?? [])
        .map(
          (i) => OrderLineItem(
            productId: i['product_id'] as String? ?? 'dummy',
            productName: i['product_name'] as String? ?? '',
            quantity: (i['quantity'] as num?)?.toDouble() ?? 1,
            unitPrice:
                (i['price_at_order'] ?? i['unit_price'] as num?)?.toDouble() ??
                0,
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

    DateTime? parseDateNullable(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final stallInfo = data['stall'] as Map<String, dynamic>?;
    final stallName =
        data['vendor_name'] as String? ??
        stallInfo?['stall_name'] as String? ??
        'Market Stall';
    final stallImage =
        data['vendor_image'] as String? ??
        stallInfo?['thumbnail_url'] as String? ??
        stallInfo?['banner_image_url'] as String? ??
        '';

    return MarketOrder(
      id: (data['order_id'] ?? data['id'])?.toString() ?? '',
      stallId: data['stall_holder_id']?.toString(),
      customerUid:
          data['customer_uid']?.toString() ?? data['customer_id']?.toString(),
      vendorName: stallName,
      vendorImage: stallImage,
      customerName: data['customer_name'] as String? ?? 'Customer',
      customerPhone: data['customer_phone'] as String?,
      status: OrderStatus.values.firstWhere(
        (s) => s.name == _appStatus(data['order_status'] ?? data['status']),
        orElse: () => OrderStatus.pending,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (s) => s.name == (data['payment_status'] as String? ?? 'pending'),
        orElse: () => PaymentStatus.pending,
      ),
      paymentMethod: data['payment_method'] as String? ?? 'cod',
      fulfillmentMethod: FulfillmentMethod.values.firstWhere(
        (f) =>
            f.name ==
            (data['fulfillment_type'] ??
                data['fulfillment_method'] as String? ??
                'pickup'),
        orElse: () => FulfillmentMethod.pickup,
      ),
      deliveryAddress: data['delivery_address'] as String?,
      deliveryLatitude: (data['delivery_latitude'] as num?)?.toDouble(),
      deliveryLongitude: (data['delivery_longitude'] as num?)?.toDouble(),
      deliveryDistanceKm:
          (data['distance_km'] ?? data['delivery_distance_km'] as num?)
              ?.toDouble(),
      deliveryFee: (data['delivery_fee'] as num?)?.toDouble() ?? 0,
      serviceFee: (data['service_fee'] as num?)?.toDouble() ?? 0,
      isPriority: data['is_priority'] as bool? ?? false,
      priorityFee: (data['priority_fee'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'] as String?,
      placedAt: parseDate(data['created_at'] ?? data['placed_at']),
      estimatedReadyTime: parseDateNullable(data['estimated_ready_time']),
      cancellationReason: data['cancellation_reason'] as String?,
      refundRequestReason: data['refund_request_reason'] as String?,
      refundRequestedAt: parseDateNullable(data['refund_requested_at']),
      refundedAmount: (data['refunded_amount'] as num?)?.toDouble() ?? 0.0,
      refundId: data['refund_id'] as String?,
      items: items,
    );
  }
}
