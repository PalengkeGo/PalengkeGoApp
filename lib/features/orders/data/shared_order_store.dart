import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/order_status_history.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';

/// Injected singleton holding the mock order book. The app root pre-loads one
/// instance from secure storage and overrides [orderStoreProvider] with it, so
/// repositories and services share the same store without global statics.
final orderStoreProvider = Provider<SharedOrderStore>(
  (ref) => SharedOrderStore(),
);

class SharedOrderStore {
  SharedOrderStore();

  final List<MarketOrder> orders = [];
  final Map<String, List<OrderStatusHistory>> history = {};
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const _ordersKey = 'mock_orders';
  static const _historyKey = 'mock_order_history';

  /// Demo orders shown in mock mode until the user places their own. Kept
  /// deliberately anonymous — no customer names or addresses.
  static final List<MarketOrder> defaultOrders = [
    MarketOrder(
      id: '#88293',
      customerUid: 'customer-001',
      stallId: 'stall holder-001',
      vendorName: 'Diosa Fruit Stand',
      vendorImage:
          'https://images.unsplash.com/photo-1488459716781-31db52582fe9?q=80&w=200&auto=format&fit=crop',
      status: OrderStatus.completed,
      placedAt: DateTime.now().subtract(const Duration(days: 2)),
      paymentStatus: PaymentStatus.paid,
      fulfillmentMethod: FulfillmentMethod.delivery,
      deliveryFee: FeeConfig.deliveryFee,
      serviceFee: FeeConfig.serviceFee,
      items: const [
        OrderLineItem(
          productId: 'dummy_pineapple',
          productName: 'Pineapple',
          quantity: 1,
          unitPrice: 55,
          unit: 'pc',
          image:
              'https://images.unsplash.com/photo-1550258987-190a2d41a8ba?w=300&h=300&fit=crop',
        ),
      ],
    ),
    MarketOrder(
      id: '#88102',
      customerUid: 'customer-001',
      stallId: 'stall holder-001',
      vendorName: 'Diosa Fruit Stand',
      vendorImage:
          'https://images.unsplash.com/photo-1488459716781-31db52582fe9?q=80&w=200&auto=format&fit=crop',
      status: OrderStatus.completed,
      placedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      paymentStatus: PaymentStatus.pending,
      fulfillmentMethod: FulfillmentMethod.pickup,
      deliveryFee: 0.0,
      serviceFee: FeeConfig.serviceFee,
      items: const [
        OrderLineItem(
          productId: 'dummy_mangoes',
          productName: 'Mangoes',
          quantity: 2,
          unitPrice: 70,
          unit: 'kg',
          image:
              'https://images.unsplash.com/photo-1553279768-865429fa0078?w=300&h=300&fit=crop',
        ),
      ],
    ),
  ];

  static final Map<String, List<OrderStatusHistory>> _defaultHistory = {
    '#88293': [
      OrderStatusHistory(
        historyId: 'h1',
        orderId: '#88293',
        newStatus: OrderStatus.pending,
        changedBy: 'customer-001',
        changedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      OrderStatusHistory(
        historyId: 'h2',
        orderId: '#88293',
        previousStatus: OrderStatus.pending,
        newStatus: OrderStatus.completed,
        changedBy: 'stall holder-001',
        changedAt: DateTime.now().subtract(const Duration(days: 2, hours: 23)),
      ),
    ],
    '#88102': [
      OrderStatusHistory(
        historyId: 'h3',
        orderId: '#88102',
        newStatus: OrderStatus.pending,
        changedBy: 'customer-001',
        changedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      OrderStatusHistory(
        historyId: 'h4',
        orderId: '#88102',
        previousStatus: OrderStatus.pending,
        newStatus: OrderStatus.completed,
        changedBy: 'stall holder-001',
        changedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ],
  };

  Future<void> load() async {
    orders.clear();
    history.clear();

    String? ordersJson;
    String? historyJson;
    try {
      ordersJson = await _storage.read(key: _ordersKey);
      historyJson = await _storage.read(key: _historyKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SharedOrderStore: Secure storage unavailable: $e');
      }
    }

    if (ordersJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(ordersJson);
        orders.addAll(
          decoded.map(
            (item) => MarketOrder.fromJson(item as Map<String, dynamic>),
          ),
        );
        if (kDebugMode) {
          debugPrint(
            "SharedOrderStore: Loaded ${orders.length} orders from storage.",
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            "SharedOrderStore: Error parsing orders, falling back to defaults: $e",
          );
        }
        orders.addAll(defaultOrders);
      }
    } else {
      if (kDebugMode) {
        debugPrint("SharedOrderStore: No orders in storage, using defaults.");
      }
      orders.addAll(defaultOrders);
    }

    if (historyJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(historyJson);
        decoded.forEach((key, value) {
          final List<dynamic> list = value as List<dynamic>;
          history[key] = list
              .map(
                (item) => OrderStatusHistory.fromFirestore(
                  item as Map<String, dynamic>,
                  id: item['historyId'] ?? '',
                ),
              )
              .toList();
        });
        if (kDebugMode) {
          debugPrint(
            "SharedOrderStore: Loaded history for ${history.keys.length} orders.",
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            "SharedOrderStore: Error parsing history, falling back to defaults: $e",
          );
        }
        history.addAll(_defaultHistory);
      }
    } else {
      if (kDebugMode) {
        debugPrint("SharedOrderStore: No history in storage, using defaults.");
      }
      history.addAll(_defaultHistory);
    }
  }

  Future<void> save() async {
    try {
      // Explicitly call toJson on nested items to avoid JsonUnsupportedObjectError
      final List<Map<String, dynamic>> serializedOrders = orders.map((o) {
        final json = o.toJson();
        json['items'] = o.items.map((i) => i.toJson()).toList();
        return json;
      }).toList();

      final ordersJson = jsonEncode(serializedOrders);

      final Map<String, dynamic> serializedHistory = history.map((key, value) {
        return MapEntry(
          key,
          value
              .map((h) => h.toFirestore()..['historyId'] = h.historyId)
              .toList(),
        );
      });
      final historyJson = jsonEncode(serializedHistory);

      await _storage.write(key: _ordersKey, value: ordersJson);
      await _storage.write(key: _historyKey, value: historyJson);
      if (kDebugMode) debugPrint("SharedOrderStore: Saved successfully!");
    } catch (e, stack) {
      if (kDebugMode) debugPrint("SharedOrderStore: Error saving: $e\n$stack");
    }
  }

  Future<void> clear() async {
    orders.clear();
    history.clear();
    await save();
  }
}
