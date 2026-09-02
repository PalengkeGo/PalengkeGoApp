import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/vendors/domain/vendor_product.dart';

class RecommendedIngredientStoresRouteArgs {
  const RecommendedIngredientStoresRouteArgs({
    required this.ingredientName,
    this.recipeTitle,
  });

  final String ingredientName;
  final String? recipeTitle;
}

class MainRouteArgs {
  const MainRouteArgs({this.initialIndex = 0});

  final int initialIndex;
}

class PaymentMethodsRouteArgs {
  const PaymentMethodsRouteArgs({
    this.currentMethod = 'cod',
    this.fulfillmentMethod = 'delivery',
    this.isManageMode = false,
  });

  final String currentMethod;
  final String fulfillmentMethod;
  final bool isManageMode;
}

class OrderConfirmationRouteArgs {
  const OrderConfirmationRouteArgs({
    required this.isPickup,
    required this.orders,
    this.address,
  });

  final bool isPickup;
  final List<MarketOrder> orders;
  final String? address;
}

class TrackOrderRouteArgs {
  const TrackOrderRouteArgs({required this.order, required this.isPickup});

  final MarketOrder order;
  final bool isPickup;
}

class OrderDetailsRouteArgs {
  const OrderDetailsRouteArgs({required this.order});

  final MarketOrder order;
}

class VendorProfileRouteArgs {
  const VendorProfileRouteArgs({required this.vendorId});
  final String vendorId;
}

class VendorReviewsRouteArgs {
  const VendorReviewsRouteArgs({required this.vendorId});
  final String vendorId;
}

class VendorAddProductRouteArgs {
  const VendorAddProductRouteArgs({this.existingProduct});
  final VendorProduct? existingProduct;
}
