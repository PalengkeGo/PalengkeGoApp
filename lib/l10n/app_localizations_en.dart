// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get homeDeliveryTo => 'Delivery to';

  @override
  String get homePopularStalls => 'Popular Stalls';

  @override
  String get searchHint => 'Search products, stalls...';

  @override
  String get cartTitle => 'Shopping Cart';

  @override
  String get cartProceed => 'Proceed to Checkout';

  @override
  String get cartEmptyTitle => 'Your cart is empty';

  @override
  String get cartEmptyHint => 'Start adding items from the market';

  @override
  String cartDeliverTo(String address) {
    return 'Deliver to $address';
  }

  @override
  String get cartTotal => 'Total';

  @override
  String get cartCheckout => 'Checkout';

  @override
  String get cartMaxStock => 'Maximum stock reached';

  @override
  String get cancel => 'Cancel';

  @override
  String get proceed => 'Proceed';

  @override
  String get checkoutSectionTitle => 'Checkout';

  @override
  String get deliveryAddressTitle => 'Delivery Address';

  @override
  String get paymentMethodTitle => 'Payment Method';

  @override
  String get orderSummaryTitle => 'Order Summary';

  @override
  String get orderNotesTitle => 'Order Notes / Instructions';

  @override
  String notesForVendor(String vendorName) {
    return 'Notes for $vendorName';
  }

  @override
  String get summarySubtotal => 'Subtotal';

  @override
  String get summaryDeliveryFee => 'Delivery Fee';

  @override
  String get feeFree => 'FREE';

  @override
  String get summaryPriorityFee => 'Priority Delivery Fee';

  @override
  String get summaryTotal => 'Total';

  @override
  String get placeOrder => 'Place Order';

  @override
  String get confirm => 'Confirm';

  @override
  String get codSelected => 'Cash on Delivery selected';

  @override
  String get gcashSelected => 'GCash selected';

  @override
  String get cardSelected => 'Card selected';

  @override
  String get paymentMethodUpdated => 'Payment method updated';

  @override
  String get deliveryMethod => 'Delivery';

  @override
  String get pickupMethod => 'Pick-Up';
}
