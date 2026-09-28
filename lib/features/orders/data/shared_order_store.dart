import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_status_history.dart';

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

  /// No mock demo orders — only real user-placed orders are displayed.
  static const List<MarketOrder> defaultOrders = <MarketOrder>[];

  static const Map<String, List<OrderStatusHistory>> _defaultHistory =
      <String, List<OrderStatusHistory>>{};

  Future<void>? _pendingSave;
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> load({bool force = false}) async {
    if (_pendingSave != null) {
      await _pendingSave;
    }
    if (_isLoaded && !force) return;
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
      orders.clear();
      try {
        final List<dynamic> decoded = jsonDecode(ordersJson);
        orders.addAll(
          decoded.map(
            (item) => MarketOrder.fromJson(item as Map<String, dynamic>),
          ),
        );
        // Strip any legacy mock demo orders so they never show in pending or completed
        orders.removeWhere((o) =>
            o.customerUid?.startsWith('cust-demo') == true ||
            o.id == '#88293' ||
            o.id == '#88102' ||
            o.id.startsWith('#2026090') ||
            ((o.customerUid == null || o.customerUid!.isEmpty) &&
                (o.customerName == 'Maria Santos' ||
                    o.customerName == 'Juan Dela Cruz' ||
                    o.customerName == 'Ana Reyes' ||
                    o.customerName == 'Carlos Ramos' ||
                    o.customerName == 'Elena Cruz')));
        if (kDebugMode) {
          debugPrint(
            "SharedOrderStore: Loaded ${orders.length} orders from storage.",
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            "SharedOrderStore: Error parsing orders: $e",
          );
        }
      }
    }

    if (historyJson != null) {
      history.clear();
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
    _isLoaded = true;
  }

  Future<void> save() async {
    final saveFuture = _performSave();
    _pendingSave = saveFuture;
    try {
      await saveFuture;
    } finally {
      if (_pendingSave == saveFuture) {
        _pendingSave = null;
      }
    }
  }

  Future<void> _performSave() async {
    _isLoaded = true;
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
    _isLoaded = false;
    orders.clear();
    history.clear();
    await save();
  }
}
