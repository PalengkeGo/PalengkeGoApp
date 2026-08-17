import 'package:palengkego/core/config/fee_config.dart';
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
  });

  final int deliveryMethod;
  final bool isPriority;
  final bool placingOrder;

  CheckoutState copyWith({
    int? deliveryMethod,
    bool? isPriority,
    bool? placingOrder,
  }) {
    return CheckoutState(
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      isPriority: isPriority ?? this.isPriority,
      placingOrder: placingOrder ?? this.placingOrder,
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
}

final checkoutProvider =
    NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);
