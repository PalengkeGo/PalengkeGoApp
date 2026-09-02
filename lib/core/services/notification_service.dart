import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  NotificationService({
    bool isTest = false,
    RecipeRepository? recipeRepository,
    SharedOrderStore? orderStore,
  }) : recipeRepository = recipeRepository ?? MockRecipeRepository(),
       orderStore = orderStore ?? SharedOrderStore(),
       _localNotificationsPlugin = isTest
             ? null
             : FlutterLocalNotificationsPlugin() {
         if (_localNotificationsPlugin != null) {
           _initLocalNotifications();
         }
       }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;
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

    try {
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
    if (kIsWeb) return;
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

  void addNotification(AppNotification notification) {
    _notifications.add(notification);
    notifyListeners();
  }

  void markRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
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
    if (changed) notifyListeners();
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
        customerTitle = 'Order $orderId is being prepared!';
        final timeStr = estimatedReadyTime != null
            ? 'estimated to be ready at ${DateFormat('h:mm a').format(estimatedReadyTime)}'
            : 'estimated ready time is pending';
        customerBody =
            '$vendorName has started preparing your order ($timeStr).';
        vendorTitle = 'You accepted order $orderId';
        vendorBody = 'Order is now in preparation.';
        break;
      case OrderStatus.ready:
        customerTitle = 'Order $orderId is ready for pick-up!';
        customerBody =
            'Your order from $vendorName is packed and ready for pick-up.';
        vendorTitle = 'Order $orderId marked ready';
        vendorBody = 'Customer has been notified that the order is ready for pick-up.';
        break;
      case OrderStatus.outForDelivery:
        customerTitle = 'Order $orderId is out for delivery!';
        customerBody =
            'Your order from $vendorName is on the way to your delivery address.';
        vendorTitle = 'Order $orderId out for delivery';
        vendorBody = 'Order has been dispatched and is en route.';
        break;
      case OrderStatus.completed:
        customerTitle = 'Order $orderId completed';
        customerBody =
            'Your order from $vendorName has been completed. Thanks for shopping!';
        vendorTitle = 'Order $orderId marked complete';
        vendorBody = 'Earnings from this order will be reflected shortly.';
        break;
      case OrderStatus.cancelled:
        customerTitle = 'Order $orderId was cancelled';
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

    // Pop native OS system notification outside the app for customer milestones
    if (newStatus == OrderStatus.ready ||
        newStatus == OrderStatus.outForDelivery) {
      if (customerTitle != null && customerBody != null) {
        showLocalNotification(
          id: orderId.hashCode,
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
