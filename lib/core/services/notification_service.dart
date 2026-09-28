import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
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
    final title = json['title'] as String? ?? '';
    final id = json['id'] as String? ?? '';
    final body = json['body'] as String? ?? '';
    final targetStr = json['target'] as String?;

    NotificationTarget target;
    if (targetStr != null) {
      target = NotificationTarget.values.firstWhere(
        (e) => e.name == targetStr,
        orElse: () => NotificationTarget.customer,
      );
    } else {
      target = NotificationTarget.customer;
    }

    if (title.toLowerCase().contains('order arrived') ||
        title.toLowerCase().contains('new order') ||
        body.toLowerCase().contains('has arrived') ||
        id.startsWith('vend_') ||
        id.startsWith('seed-vendor')) {
      target = NotificationTarget.vendor;
    }

    return AppNotification(
      id: id,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.promo,
      ),
      target: target,
      title: title,
      body: body,
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
  bool _disposed = false;

  NotificationService({
    bool? isTest,
    RecipeRepository? recipeRepository,
    SharedOrderStore? orderStore,
  }) : isTest = isTest ??
           (WidgetsBinding.instance.runtimeType.toString().contains('Test') ||
               (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))),
       recipeRepository = recipeRepository ?? MockRecipeRepository(),
       orderStore = orderStore ?? SharedOrderStore(),
       _localNotificationsPlugin = (isTest ??
               (WidgetsBinding.instance.runtimeType.toString().contains('Test') ||
                   (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))))
           ? null
           : FlutterLocalNotificationsPlugin() {
    if (!this.isTest) {
      _loadPersistedNotifications();
    }
    if (_localNotificationsPlugin != null) {
      _initLocalNotifications();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
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

  /// Returns true if this notification is intended exclusively for vendors/stall holders.
  static bool isVendorNotification(AppNotification n) {
    if (n.target == NotificationTarget.vendor) return true;
    final title = n.title.toLowerCase();
    final body = n.body.toLowerCase();
    final id = n.id.toLowerCase();
    if (title.contains('order arrived') ||
        title.contains('new order') ||
        title.contains('refund request') ||
        title.contains('you accepted order') ||
        title.contains('marked ready') ||
        body.contains('has arrived') ||
        id.startsWith('vend_') ||
        id.startsWith('seed-vendor')) {
      return true;
    }
    return false;
  }

  /// Returns true if this notification is intended exclusively for customers.
  static bool isCustomerOnlyNotification(AppNotification n) {
    if (n.target == NotificationTarget.customer) return true;
    final title = n.title.toLowerCase();
    if (title.contains('order placed') ||
        title.contains('prep time updated') ||
        title.contains('ready for pick-up') ||
        title.contains('out for delivery') ||
        title.contains('picked up') ||
        title.contains('delivered') ||
        title.contains('special offer')) {
      return true;
    }
    return false;
  }

  List<AppNotification> get forCustomer => all
      .where(
        (n) =>
            !isVendorNotification(n) &&
            (n.target == NotificationTarget.customer ||
                n.target == NotificationTarget.both),
      )
      .toList();

  List<AppNotification> get forVendor => all
      .where(
        (n) =>
            isVendorNotification(n) ||
            n.target == NotificationTarget.vendor ||
            (n.target == NotificationTarget.both &&
                !isCustomerOnlyNotification(n)),
      )
      .toList();

  int get customerUnreadCount => forCustomer.where((n) => !n.isRead).length;
  int get vendorUnreadCount => forVendor.where((n) => !n.isRead).length;

  static List<AppNotification> get defaultSeedNotifications => [
        AppNotification(
          id: 'seed-special-offer-1',
          type: NotificationType.promo,
          target: NotificationTarget.customer,
          title: 'Special Offers Alert: Fresh Discounts Available! 🏷️',
          body:
              'Check out special discounts on fresh fruits, seafood, and market favorites on Special Offers today!',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        AppNotification(
          id: 'seed-1',
          type: NotificationType.promo,
          target: NotificationTarget.customer,
          title: 'Special Offer: Organic Week at Diosa Fruit Stand! 🍏',
          body:
              '20% off on fresh seasonal fruits. Valid until Sunday.',
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
          referenceId: 'v1',
        ),
        AppNotification(
          id: 'seed-announcement-1',
          type: NotificationType.admin,
          target: NotificationTarget.both,
          title: '📢 MEPO Announcement: Naga People\'s Mall Advisory',
          body:
              'Palengke operates 5:00 AM to 7:00 PM daily. Please follow market safety guidelines.',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        AppNotification(
          id: 'seed-vendor-order-1',
          type: NotificationType.order,
          target: NotificationTarget.vendor,
          title: 'New Order Arrived! 🔔',
          body: 'An order has arrived from Maria Santos (San Felipe, Naga City).',
          createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
          referenceId: '20260901',
        ),
        AppNotification(
          id: 'seed-vendor-announcement-1',
          type: NotificationType.admin,
          target: NotificationTarget.vendor,
          title: '📢 MEPO Advisory: Wet Market Sanitization',
          body:
              'The Wet Market section will undergo routine sanitization this Sunday from 8 PM to 11 PM.',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ];

  static const _persistedNotifsKey = 'app_persisted_notifications_v3';
  bool _isLoaded = false;

  Future<void> _loadPersistedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Purge legacy keys that may contain incorrectly targeted entries
      await prefs.remove('app_persisted_notifications_v1');
      await prefs.remove('app_persisted_notifications_v2');

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
    bool isPickup = false,
  }) {
    String? customerTitle;
    String? customerBody;

    switch (newStatus) {
      case OrderStatus.preparing:
        final timeStr = estimatedReadyTime != null
            ? ' (estimated ready at ${DateFormat('h:mm a').format(estimatedReadyTime)})'
            : '';
        customerTitle = 'Order $orderId Accepted! 🍳';
        customerBody =
            '$vendorName accepted your order and is now preparing it$timeStr.';
        break;
      case OrderStatus.ready:
        if (isPickup) {
          customerTitle = 'Order $orderId Ready for Pick-Up! 🛍️';
          customerBody =
              'Your order from $vendorName is packed and ready for pick-up at the stall.';
        } else {
          customerTitle = 'Order $orderId Packed & Ready! 🛍️';
          customerBody =
              'Your order from $vendorName is packed and awaiting rider dispatch.';
        }
        break;
      case OrderStatus.outForDelivery:
        customerTitle = 'Order $orderId Out for Delivery! 🛵';
        customerBody =
            'Your delivery from $vendorName is on the way to your delivery address!';
        break;
      case OrderStatus.completed:
        if (isPickup) {
          customerTitle = 'Order $orderId Picked Up! 🎉';
          customerBody =
              'You have picked up your order from $vendorName. Thank you for shopping local!';
        } else {
          customerTitle = 'Order $orderId Delivered! 📦';
          customerBody =
              'Your order from $vendorName has been delivered. Thank you for shopping local!';
        }
        break;
      case OrderStatus.cancelled:
        customerTitle = 'Order $orderId Cancelled';
        customerBody = 'Your order from $vendorName was cancelled.';
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
          channelId: 'palengkego_order_updates',
          channelName: 'Order Updates',
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

  /// Fires when a vendor updates prep / ready time for a pending or preparing order
  Future<void> onPrepTimeUpdated(
    String orderId,
    String vendorName,
    DateTime estimatedReadyTime, {
    bool isPickup = true,
  }) async {
    final timeStr = DateFormat('h:mm a').format(estimatedReadyTime);
    final customerTitle = isPickup
        ? 'Prep Time Updated for Pick-Up! ⏱️'
        : 'Estimated Delivery Time Updated! ⏱️';
    final customerBody = isPickup
        ? '$vendorName set estimated pick-up ready time to $timeStr. Head to the stall then!'
        : '$vendorName set estimated delivery arrival time to $timeStr.';

    final now = DateTime.now();
    addNotification(
      AppNotification(
        id: '${orderId}_prepTime_${now.millisecondsSinceEpoch}',
        type: NotificationType.order,
        target: NotificationTarget.customer,
        title: customerTitle,
        body: customerBody,
        createdAt: now,
        referenceId: orderId,
      ),
    );
    await showLocalNotification(
      id: ('${orderId}_prepTime').hashCode,
      title: customerTitle,
      body: customerBody,
      channelId: 'palengkego_order_updates',
      channelName: 'Order Updates',
    );
  }

  /// Fires when a stall holder offers a special promotion / discount
  Future<void> onSpecialOffer({
    required String offerId,
    required String stallName,
    required String title,
    required String body,
    String? vendorId,
    String? productId,
  }) async {
    final now = DateTime.now();
    final refId = (vendorId != null && productId != null)
        ? '$vendorId:$productId'
        : (vendorId ?? offerId);
    addNotification(
      AppNotification(
        id: 'special_offer_${offerId}_${now.millisecondsSinceEpoch}',
        type: NotificationType.promo,
        target: NotificationTarget.customer,
        title: 'Special Offer from $stallName: $title 🏷️',
        body: body,
        createdAt: now,
        referenceId: refId,
      ),
    );
    await showLocalNotification(
      id: ('offer_$offerId').hashCode,
      title: 'Special Offer from $stallName 🏷️',
      body: '$title — $body',
      channelId: 'palengkego_promos',
      channelName: 'Special Offers',
    );
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

  /// Helper to format a customer's full name to first and last name only
  static String formatFirstAndLastName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Customer';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length <= 1) return parts.first;
    return '${parts.first} ${parts.last}';
  }

  /// Fires when a new order arrives for a vendor (both in-app and native OS notification).
  Future<void> onNewOrderArrived(
    String orderId,
    String customerName,
    double total, {
    String? deliveryAddress,
    bool isPickup = false,
  }) async {
    final displayName = formatFirstAndLastName(customerName);
    String addressText = '';
    if (isPickup) {
      addressText = ' (Store Pick-Up)';
    } else if (deliveryAddress != null && deliveryAddress.trim().isNotEmpty) {
      addressText = ' (${deliveryAddress.trim()})';
    }
    final notifBody = 'An order has arrived from $displayName$addressText.';

    if (_notifications.any((n) => n.referenceId == orderId && n.target == NotificationTarget.vendor)) {
      return;
    }

    if (isTest) {
      final now = DateTime.now();
      addNotification(
        AppNotification(
          id: 'vend_order_${orderId}_${now.millisecondsSinceEpoch}',
          type: NotificationType.order,
          target: NotificationTarget.vendor,
          title: 'New Order Arrived! 🔔',
          body: notifBody,
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
        body: notifBody,
        createdAt: now,
        referenceId: orderId,
      ),
    );
    await showLocalNotification(
      id: ('vendor_$orderId').hashCode,
      title: 'New Order Arrived! 🔔',
      body: notifBody,
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
