import 'package:cloud_functions/cloud_functions.dart';
import 'package:palengkego/core/config/fee_config.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/infrastructure/paymongo_service.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/orders/application/order_provider.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_failure.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/profile/application/preferences_provider.dart';
import 'package:palengkego/features/profile/application/profile_provider.dart';

/// Mutable checkout form state.
class CheckoutState {
  const CheckoutState({
    this.deliveryMethod = 0, // 0 = Delivery, 1 = Pick-Up
    this.isPriority = false,
    this.placingOrder = false,
    this.paymentSessions = const {},
    this.paymentFailures = const {},
  });

  final int deliveryMethod;
  final bool isPriority;
  final bool placingOrder;

  /// Orders placed with an online method, keyed by orderId → the PayMongo
  /// approval page to open (null = already processing, no redirect needed).
  final Map<String, String?> paymentSessions;

  /// Orders whose payment could not be initiated, keyed by orderId →
  /// user-readable reason. The order exists; payment can be retried from the
  /// confirmation screen or the order tracker.
  final Map<String, String> paymentFailures;

  CheckoutState copyWith({
    int? deliveryMethod,
    bool? isPriority,
    bool? placingOrder,
    Map<String, String?>? paymentSessions,
    Map<String, String>? paymentFailures,
  }) {
    return CheckoutState(
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      isPriority: isPriority ?? this.isPriority,
      placingOrder: placingOrder ?? this.placingOrder,
      paymentSessions: paymentSessions ?? this.paymentSessions,
      paymentFailures: paymentFailures ?? this.paymentFailures,
    );
  }

  double get priorityFee {
    return (deliveryMethod == 0 && isPriority) ? FeeConfig.priorityFee : 0.0;
  }
}

/// State + order placement logic for the checkout screen.
class CheckoutController extends Notifier<CheckoutState> {
  final Map<String, TextEditingController> _vendorNotesControllers = {};

  @override
  CheckoutState build() {
    ref.onDispose(() {
      for (final controller in _vendorNotesControllers.values) {
        controller.dispose();
      }
      _vendorNotesControllers.clear();
    });
    return const CheckoutState();
  }

  TextEditingController notesControllerFor(String vendorName) {
    return _vendorNotesControllers.putIfAbsent(
      vendorName,
      () => TextEditingController(),
    );
  }

  void setDeliveryMethod(int value) {
    state = state.copyWith(deliveryMethod: value);
  }

  void setPriority(bool value) {
    state = state.copyWith(isPriority: value);
  }

  /// Groups the selected items by vendor and places the orders.
  /// Returns the created orders, or null (with an error shown) on failure.
  Future<List<MarketOrder>?> placeOrder({
    required List<CartItem> selectedItems,
  }) async {
    state = state.copyWith(placingOrder: true);

    final Map<String, String> vendorNotes = {};
    for (final entry in _vendorNotesControllers.entries) {
      final text = entry.value.text.trim();
      if (text.isNotEmpty) {
        vendorNotes[entry.key] = text;
      }
    }

    final profile = ref.read(currentProfileProvider).value;
    final customerName = profile?.displayName ?? 'Customer';
    final customerUid = ref.read(authProvider)?.uid ?? '';
    final paymentMethod = ref.read(preferencesProvider).paymentMethod;

    // Preferred address comes from customer preferences; fall back to the
    // profile's saved default, then a sensible placeholder.
    final isPickup = state.deliveryMethod == 1;
    final userAddress =
        ref.read(preferencesProvider).deliveryAddress.fullAddress;
    final profileAddress = profile?.defaultAddress?.fullAddress;
    final deliveryAddress = isPickup
        ? null
        : (userAddress.isNotEmpty
            ? userAddress
            : (profileAddress?.isNotEmpty == true
                ? profileAddress!
                : 'San Felipe, Naga City'));

    try {
      final Map<String, (String, List<OrderLineItem>)> groupedItems = {};
      for (final item in selectedItems) {
        groupedItems.putIfAbsent(
          item.vendorName,
          () => (item.image, <OrderLineItem>[]),
        );
        groupedItems[item.vendorName]!.$2.add(
          OrderLineItem(
            productId: item.productId,
            productName: item.productName,
            quantity: item.quantity,
            unitPrice: item.price,
            unit: item.unit,
            image: item.image,
          ),
        );
      }

      final createdOrders = await ref
          .read(orderRepositoryProvider)
          .placeOrders(
            groupedItems: groupedItems,
            isPickup: isPickup,
            vendorNotes: vendorNotes.isNotEmpty ? vendorNotes : null,
            customerName: customerName,
            customerUid: customerUid,
            deliveryAddress: deliveryAddress,
            isPriority: !isPickup && state.isPriority,
            priorityFee: state.priorityFee,
            paymentMethod: paymentMethod,
          );

      ref.read(orderServiceProvider.notifier).refresh();
      ref.read(cartItemsProvider.notifier).removeSelectedItems();

      await _initiateOnlinePayments(createdOrders, paymentMethod);
      return createdOrders;
    } on OrderFailure catch (e) {
      AppServices.showError(e.message);
      return null;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('Error placing order: $e');
      if (kDebugMode) debugPrint('Stacktrace: $stack');
      AppServices.showError(
        'Failed to place your order. Your cart is unchanged — please try again.',
      );
      return null;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(placingOrder: false);
      }
    }
  }

  /// For orders placed with an online method (gcash/paymaya/card), create the
  /// PayMongo payment session so the confirmation screen can send the customer
  /// to the approval page. Failures are recorded per order — the order stays
  /// placed and payment remains retryable, so nothing here throws.
  Future<void> _initiateOnlinePayments(
    List<MarketOrder> orders,
    String paymentMethod,
  ) async {
    final sessions = <String, String?>{};
    final failures = <String, String>{};

    if (ref.read(firebaseEnabledProvider) && _isOnlineMethod(paymentMethod)) {
      for (final order in orders) {
        final (url, error) = await _startSessionFor(order.id, paymentMethod);
        if (error != null) {
          failures[order.id] = error;
        } else {
          sessions[order.id] = url;
        }
      }
    }

    if (ref.mounted) {
      state = state.copyWith(
        paymentSessions: sessions,
        paymentFailures: failures,
      );
    }
  }

  /// Starts (or retries) the payment session for one order. Returns the
  /// redirect URL (null = processing, no redirect) or an error message.
  Future<(String?, String?)> _startSessionFor(
    String orderId,
    String paymentMethod,
  ) async {
    try {
      final session = await ref
          .read(paymongoServiceProvider)
          .startPayment(orderId: orderId, method: paymentMethod);
      return (session.redirectUrl, null);
    } on CardPaymentUnsupportedError {
      return (
        null,
        'Card payments need card details in-app — pay with GCash/Maya or '
            'choose cash. Your order is reserved.',
      );
    } on PaymentInitiationException catch (e) {
      return (
        null,
        'Payment could not be started (${e.message}). Tap retry in a moment.',
      );
    } on FirebaseFunctionsException catch (e) {
      return (
        null,
        'Payment could not be started (${e.message ?? 'backend error'}). Tap '
            'retry in a moment.',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Payment initiation failed: $e');
      return (
        null,
        'Payment could not be started. Tap retry in a moment.',
      );
    }
  }

  /// Retries payment initiation for one order from the confirmation screen.
  /// Only meaningful in Firebase mode with an online method selected.
  Future<void> retryPayment(String orderId) async {
    final method = ref.read(preferencesProvider).paymentMethod;
    if (!ref.read(firebaseEnabledProvider) || !_isOnlineMethod(method)) {
      return;
    }
    final (url, error) = await _startSessionFor(orderId, method);
    if (!ref.mounted) return;
    final sessions = Map<String, String?>.from(state.paymentSessions);
    final failures = Map<String, String>.from(state.paymentFailures);
    failures.remove(orderId);
    if (error != null) {
      sessions.remove(orderId);
      failures[orderId] = error;
    } else {
      sessions[orderId] = url;
    }
    state = state.copyWith(
      paymentSessions: sessions,
      paymentFailures: failures,
    );
  }

  bool _isOnlineMethod(String method) =>
      method == 'gcash' || method == 'paymaya' || method == 'card';
}

final checkoutProvider =
    NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);
