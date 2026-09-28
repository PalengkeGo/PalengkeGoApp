import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/data/shared_order_store.dart';
import 'package:palengkego/features/recipes/data/mock_recipe_repository.dart';
import 'package:palengkego/features/recipes/data/recipe_repository.dart';
import 'package:palengkego/features/recipes/domain/recipe.dart';


/// The audience this notification is aimed at.
enum NotificationTarget { customer, vendor, both }

/// Type determines which icon / color to use in the UI.
enum NotificationType { order, stock, review, promo, admin, recipe, refund }

/// Immutable in-app notification.
class AppNotification {
  final String id;
  final NotificationType type;
  final NotificationTarget target;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Optional reference to the entity this notification is about.
  /// e.g. an orderId, stallId, or promoId — used for deep-link navigation
  /// when the user taps the notification.
  final String? referenceId;

  const AppNotification({
    required this.id,
    required this.type,
    required this.target,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.referenceId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'target': target.name,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        'referenceId': referenceId,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.promo,
      ),
      target: NotificationTarget.values.firstWhere(
        (e) => e.name == json['target'],
        orElse: () => NotificationTarget.both,
      ),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      referenceId: json['referenceId'] as String?,
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      target: target,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      referenceId: referenceId,
    );
  }
}

/// In-app notification store.
class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin? _localNotificationsPlugin;

  /// Recipe content source used for post-order recipe suggestions. Injected so
  /// it follows the environment-selected backend (mock in dev, Supabase when
  /// configured) instead of a hardcoded static.
  final RecipeRepository recipeRepository;

  /// Order book read when a completed order should unlock a recipe suggestion.
  final SharedOrderStore orderStore;
  final bool isTest;

  NotificationService({
    this.isTest = false,
    RecipeRepository? recipeRepository,
    SharedOrderStore? orderStore,
  }) : recipeRepository = recipeRepository ?? MockRecipeRepository(),
       orderStore = orderStore ?? SharedOrderStore(),
       _localNotificationsPlugin = isTest
             ? null
             : FlutterLocalNotificationsPlugin() {
         if (!isTest) {
           _loadPersistedNotifications();
         }
         if (_localNotificationsPlugin != null) {
           _initLocalNotifications();
         }
       }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _localNotificationsPlugin?.initialize(settings: initSettings);

      await _localNotificationsPlugin
          ?.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String channelId = 'palengkego_order_updates',
    String channelName = 'Order Updates',
  }) async {
    if (kIsWeb || isTest) return;
    if (_localNotificationsPlugin == null) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription:
          'Order status updates like Ready for Pick-up and Out for Delivery',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    try {
      await _localNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Failed to show system notification: $e');
    }
  }

  /// In-app notifications. Starts empty — real notifications arrive from
  /// [addNotification] / [onOrderStatusChanged]; no demo data in production code.
  final List<AppNotification> _notifications = [];

  List<AppNotification> get all {
    final sorted = List<AppNotification>.from(_notifications);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  List<AppNotification> get forCustomer => all
      .where(
        (n) =>
            n.target == NotificationTarget.customer ||
            n.target == NotificationTarget.both,
      )
      .toList();

  List<AppNotification> get forVendor => all
      .where(
        (n) =>
            n.target == NotificationTarget.vendor ||
            n.target == NotificationTarget.both,
      )
      .toList();

  int get customerUnreadCount => forCustomer.where((n) => !n.isRead).length;
  int get vendorUnreadCount => forVendor.where((n) => !n.isRead).length;

  static List<AppNotification> get defaultSeedNotifications => [
        AppNotification(
          id: 'seed-special-offer-1',
          type: NotificationType.promo,
          target: NotificationTarget.both,
          title: 'Special Offers Alert: Fresh Discounts Available!',
          body:
              'Check out special discounts on fresh fruits, seafood, and market favorites on Special Offers today!',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        AppNotification(
          id: 'seed-1',
          type: NotificationType.promo,
          target: NotificationTarget.customer,
          title: 'Organic Week!',
          body:
              '20% off on all leafy greens across the market. Valid until Sunday.',
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        ),
        AppNotification(
          id: 'seed-2',
          type: NotificationType.promo,
          target: NotificationTarget.customer,
          title: 'Flash Sale on Seafood 🐟',
          body: '50% off on all seafood until 6 PM today. Stocks limited!',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        AppNotification(
          id: 'seed-v1',
          type: NotificationType.review,
          target: NotificationTarget.vendor,
          title: 'New 5-Star Rating!',
          body:
              'Ricardo D. left a review: "Super fresh tilapia and fast preparation. Will buy again!"',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        AppNotification(
          id: 'seed-v2',
          type: NotificationType.admin,
          target: NotificationTarget.vendor,
          title: 'Market Maintenance Notice',
          body:
              'The Wet Market section will undergo sanitization this Sunday from 8 PM to 11 PM.',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          isRead: true,
        ),
      ];

  static const _persistedNotifsKey = 'app_persisted_notifications_v1';
  bool _isLoaded = false;

  Future<void> _loadPersistedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_persistedNotifsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          final n = AppNotification.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
          if (!_notifications.any((existing) => existing.id == n.id)) {
            _notifications.add(n);
          }
        }
      }

      // If notifications are still empty, populate with default seed notifications
      if (_notifications.isEmpty) {
        _notifications.addAll(defaultSeedNotifications);
        await prefs.setString(
          _persistedNotifsKey,
          jsonEncode(_notifications.map((n) => n.toJson()).toList()),
        );
      } else {
        // Ensure default seed notifications exist so past notifications are preserved
        for (final seed in defaultSeedNotifications) {
          if (!_notifications.any((existing) => existing.id == seed.id)) {
            _notifications.add(seed);
          }
        }
      }
      _isLoaded = true;
      notifyListeners();
    } catch (_) {
      if (_notifications.isEmpty) {
        _notifications.addAll(defaultSeedNotifications);
      }
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _savePersistedNotifications() async {
    if (isTest) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _notifications.map((n) => n.toJson()).toList();
      await prefs.setString(_persistedNotifsKey, jsonEncode(list));
    } catch (_) {}
  }

  void addNotification(AppNotification notification) {
    if (_notifications.any((n) => n.id == notification.id)) return;
    _notifications.add(notification);
    if (_isLoaded) {
      _savePersistedNotifications();
    }
    notifyListeners();
  }

  void markRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _savePersistedNotifications();
      notifyListeners();
    }
  }

  void markAllRead(NotificationTarget target) {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if ((n.target == target || n.target == NotificationTarget.both) &&
          !n.isRead) {
        _notifications[i] = n.copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      _savePersistedNotifications();
      notifyListeners();
    }
  }

  void markAllOfTypeRead(NotificationType type) {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (n.type == type && !n.isRead) {
        _notifications[i] = n.copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void onOrderStatusChanged(
    String orderId,
    String vendorName,
    OrderStatus newStatus, {
    DateTime? estimatedReadyTime,
  }) {
    String? customerTitle;
    String? customerBody;
    String? vendorTitle;
    String? vendorBody;

    switch (newStatus) {
      case OrderStatus.preparing:
        customerTitle = 'Order $orderId Accepted & Preparing! 🍳';
        final timeStr = estimatedReadyTime != null
            ? 'estimated to be ready at ${DateFormat('h:mm a').format(estimatedReadyTime)}'
            : 'estimated ready time is pending';
        customerBody =
            '$vendorName accepted your order and is now preparing it ($timeStr).';
        vendorTitle = 'You accepted order $orderId';
        vendorBody = 'Order is now in preparation.';
        break;
      case OrderStatus.ready:
        customerTitle = 'Order $orderId Ready for Pick-up! 🛍️';
        customerBody =
            'Your order from $vendorName is packed and ready for pick-up.';
        vendorTitle = 'Order $orderId marked ready';
        vendorBody = 'Customer has been notified that the order is ready for pick-up.';
        break;
      case OrderStatus.outForDelivery:
        customerTitle = 'Order $orderId Out for Delivery! 🛵';
        customerBody =
            'Your order from $vendorName is on the way to your delivery address.';
        vendorTitle = 'Order $orderId out for delivery';
        vendorBody = 'Order has been dispatched and is en route.';
        break;
      case OrderStatus.completed:
        customerTitle = 'Order $orderId Complete! 🎉';
        customerBody =
            'Your order from $vendorName is now complete. Thank you for shopping local!';
        vendorTitle = 'Order $orderId marked complete';
        vendorBody = 'Earnings from this order will be reflected shortly.';
        break;
      case OrderStatus.cancelled:
        customerTitle = 'Order $orderId Cancelled';
        customerBody = 'Your order from $vendorName was cancelled.';
        vendorTitle = 'Order $orderId cancelled';
        vendorBody = 'The order has been cancelled.';
        break;
      default:
        break;
    }

    final now = DateTime.now();
    if (customerTitle != null) {
      addNotification(
        AppNotification(
          id: '${orderId}_${newStatus.name}_cust_${now.millisecondsSinceEpoch}',
          type: NotificationType.order,
          target: NotificationTarget.customer,
          title: customerTitle,
          body: customerBody ?? '',
          createdAt: now,
          referenceId: orderId,
        ),
      );
    }
    if (vendorTitle != null) {
      addNotification(
        AppNotification(
          id: '${orderId}_${newStatus.name}_vend_${now.millisecondsSinceEpoch}',
          type: NotificationType.order,
          target: NotificationTarget.vendor,
          title: vendorTitle,
          body: vendorBody ?? '',
          createdAt: now,
          referenceId: orderId,
        ),
      );
    }

    // Pop native OS system notification outside the app for all customer milestones
    if (newStatus == OrderStatus.preparing ||
        newStatus == OrderStatus.ready ||
        newStatus == OrderStatus.outForDelivery ||
        newStatus == OrderStatus.completed ||
        newStatus == OrderStatus.cancelled) {
      if (customerTitle != null && customerBody != null) {
        showLocalNotification(
          id: ('${orderId}_${newStatus.name}').hashCode,
          title: customerTitle,
          body: customerBody,
        );
      }
    }

    if (newStatus == OrderStatus.completed) {
      final ordIndex = orderStore.orders.indexWhere(
        (o) => o.id == orderId,
      );
      if (ordIndex != -1) {
        final order = orderStore.orders[ordIndex];
        unawaited(_suggestNewRecipe(order.items, order.vendorName));
      }
    }
  }

  /// Fires when a customer requests a refund on one of [vendorName]'s orders
  /// (the order's paymentStatus flips to `refundRequested`).
  ///
  /// Vendor-only — the requesting customer already sees the state on their
  /// own order card. Mirrors [onOrderStatusChanged]: in-app list entry, no
  /// local device push.
  void onRefundRequested(
    String orderId,
    String vendorName, {
    double? amount,
    String? reason,
  }) {
    final now = DateTime.now();
    final amountText = (amount != null && amount > 0)
        ? ' for ₱${amount.toStringAsFixed(2)}'
        : '';
    final reasonText = (reason == null || reason.trim().isEmpty)
        ? ''
        : ' — "${reason.trim()}"';
    addNotification(
      AppNotification(
        id: '${orderId}_refundRequested_vend_${now.millisecondsSinceEpoch}',
        type: NotificationType.refund,
        target: NotificationTarget.vendor,
        title: 'Refund request',
        body:
            'A customer requested a refund on order $orderId from $vendorName$amountText. Review it in your orders$reasonText.',
        createdAt: now,
        referenceId: orderId,
      ),
    );
  }

  /// Fires when a new order arrives for a vendor (both in-app and native OS notification).
  Future<void> onNewOrderArrived(
    String orderId,
    String customerName,
    double total,
  ) async {
    if (isTest) {
      final now = DateTime.now();
      addNotification(
        AppNotification(
          id: 'vend_order_${orderId}_${now.millisecondsSinceEpoch}',
          type: NotificationType.order,
          target: NotificationTarget.vendor,
          title: 'New Order Arrived! 🔔',
          body: 'New order #$orderId from $customerName has arrived.',
          createdAt: now,
          referenceId: orderId,
        ),
      );
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      const storageKey = 'notified_vendor_order_ids_v1';
      final notified = (prefs.getStringList(storageKey) ?? []).toSet();
      if (notified.contains(orderId)) return;
      notified.add(orderId);
      await prefs.setStringList(storageKey, notified.toList());
    } catch (_) {}

    final now = DateTime.now();
    addNotification(
      AppNotification(
        id: 'vend_order_${orderId}_${now.millisecondsSinceEpoch}',
        type: NotificationType.order,
        target: NotificationTarget.vendor,
        title: 'New Order Arrived! 🔔',
        body: 'New order #$orderId from $customerName has arrived.',
        createdAt: now,
        referenceId: orderId,
      ),
    );
    await showLocalNotification(
      id: ('vendor_$orderId').hashCode,
      title: 'New Order Arrived! 🔔',
      body:
          'New order #$orderId from $customerName (₱${total.toStringAsFixed(2)}) has arrived.',
      channelId: 'palengkego_vendor_orders',
      channelName: 'Stall Holder Orders',
    );
  }

  /// Fires when a new MEPO announcement is published (both in-app and native OS notification).
  Future<void> onNewAnnouncement({
    required String announcementId,
    required String title,
    required String body,
    required NotificationTarget target,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const storageKey = 'notified_announcement_ids_v1';
      final notified = (prefs.getStringList(storageKey) ?? []).toSet();
      if (notified.contains(announcementId)) return;
      notified.add(announcementId);
      await prefs.setStringList(storageKey, notified.toList());
    } catch (_) {}

    final now = DateTime.now();
    addNotification(
      AppNotification(
        id: 'announcement_${announcementId}_${now.millisecondsSinceEpoch}',
        type: NotificationType.admin,
        target: target,
        title: '📢 MEPO Announcement: $title',
        body: body,
        createdAt: now,
        referenceId: announcementId,
      ),
    );
    await showLocalNotification(
      id: ('announcement_$announcementId').hashCode,
      title: '📢 MEPO: $title',
      body: body,
      channelId: 'palengkego_mepo_announcements',
      channelName: 'MEPO Announcements',
    );
  }

  Future<void> _suggestNewRecipe(
    List<OrderLineItem> items,
    String vendorName,
  ) async {
    final allRecipes = await recipeRepository.getRecipes();
    final recipe = _suggestRecipe(allRecipes, items);
    if (recipe == null) return;
    await Future.delayed(const Duration(milliseconds: 500));
    final delayNow = DateTime.now();
    addNotification(
      AppNotification(
        id: 'recipe_${delayNow.millisecondsSinceEpoch}',
        type: NotificationType.recipe,
        target: NotificationTarget.customer,
        title: 'New recipe suggestion unlocked!',
        body:
            'Since your order from $vendorName is complete, try making $recipe with your ingredients! (Tap to view available recipes)',
        createdAt: delayNow,
      ),
    );
  }

  static String? _suggestRecipe(
    List<Recipe> allRecipes,
    List<OrderLineItem> items,
  ) {
    final itemNames = items.map((i) => i.productName.toLowerCase()).toList();

    for (final recipe in allRecipes) {
      final titleLower = recipe.title.toLowerCase();
      if (itemNames.any(
        (p) => titleLower.contains(p) || p.contains(titleLower),
      )) {
        return recipe.title;
      }
      if (recipe.ingredients != null) {
        for (final ing in recipe.ingredients!) {
          final ingName = ing.name.toLowerCase();
          if (itemNames.any(
            (p) => ingName.contains(p) || p.contains(ingName),
          )) {
            return recipe.title;
          }
        }
      }
    }
    return null;
  }
}
