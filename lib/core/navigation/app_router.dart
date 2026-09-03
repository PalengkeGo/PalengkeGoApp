import 'package:flutter/material.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/features/auth/presentation/pages/login_screen.dart';
import 'package:palengkego/features/auth/presentation/pages/registration_screen.dart';
import 'package:palengkego/features/cart/presentation/pages/shopping_cart_screen.dart';
import 'package:palengkego/features/checkout/presentation/pages/add_credit_card_screen.dart';
import 'package:palengkego/features/checkout/presentation/pages/checkout_screen.dart';
import 'package:palengkego/features/checkout/presentation/pages/order_confirmation_screen.dart';
import 'package:palengkego/features/checkout/presentation/pages/payment_methods_screen.dart';
import 'package:palengkego/features/main/presentation/pages/main_screen.dart';
import 'package:palengkego/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:palengkego/features/onboarding/presentation/pages/splash_screen.dart';
import 'package:palengkego/features/profile/presentation/pages/set_delivery_address_screen.dart';
import 'package:palengkego/features/recipes/presentation/pages/cookbook_screen.dart';
import 'package:palengkego/features/orders/presentation/pages/order_details_screen.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_add_product_screen.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_dashboard_screen.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_profile_screen.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_products_screen.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_reviews_screen.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_license_screen.dart';
import 'package:palengkego/features/recipes/presentation/pages/recommended_ingredient_stores_screen.dart';


class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _materialRoute(settings, const SplashScreen());
      case AppRoutes.onboarding:
        return _materialRoute(settings, const OnboardingScreen());
      case AppRoutes.login:
        return _materialRoute(settings, const LoginScreen());
      case AppRoutes.registration:
        return _materialRoute(settings, const RegistrationScreen());
      case AppRoutes.main:
        final args = settings.arguments;
        final initialIndex = args is MainRouteArgs ? args.initialIndex : 0;
        return _materialRoute(settings, MainScreen(initialIndex: initialIndex));
      case AppRoutes.cart:
        return _slideRoute(settings, const ShoppingCartScreen());
      case AppRoutes.checkout:
        return _slideRoute(settings, const AuthGuard(child: CheckoutScreen()));
      case AppRoutes.paymentMethods:
        final args = settings.arguments;
        final currentMethod = args is PaymentMethodsRouteArgs
            ? args.currentMethod
            : 'cod';
        final fulfillmentMethod = args is PaymentMethodsRouteArgs
            ? args.fulfillmentMethod
            : 'delivery';
        final isManageMode = args is PaymentMethodsRouteArgs
            ? args.isManageMode
            : false;
        return _materialRoute(
          settings,
          AuthGuard(
            child: PaymentMethodsScreen(
              currentMethod: currentMethod,
              fulfillmentMethod: fulfillmentMethod,
              isManageMode: isManageMode,
            ),
          ),
        );
      case AppRoutes.addCreditCard:
        return _materialRoute(
          settings,
          const AuthGuard(child: AddCreditCardScreen()),
        );
      case AppRoutes.orderConfirmation:
        final args = settings.arguments;
        if (args is! OrderConfirmationRouteArgs) {
          return _errorRoute(settings);
        }
        return _materialRoute(
          settings,
          AuthGuard(
            child: OrderConfirmationScreen(
              isPickup: args.isPickup,
              orders: args.orders,
              address: args.address,
            ),
          ),
        );
      case AppRoutes.trackOrder:
        final args = settings.arguments;
        if (args is! TrackOrderRouteArgs) {
          return _errorRoute(settings);
        }
        return _materialRoute(
          settings,
          AuthGuard(child: OrderDetailsScreen(order: args.order)),
        );
      case AppRoutes.setDeliveryAddress:
        return _materialRoute(settings, const SetDeliveryAddressScreen());
      case AppRoutes.cookbook:
        return _slideRoute(settings, const CookbookScreen());
      case AppRoutes.orderDetails:
        final args = settings.arguments;
        if (args is! OrderDetailsRouteArgs) {
          return _errorRoute(settings);
        }
        return _slideRoute(
          settings,
          AuthGuard(child: OrderDetailsScreen(order: args.order)),
        );
      case AppRoutes.vendorAddProduct:
        final args = settings.arguments as VendorAddProductRouteArgs?;
        return _slideRoute(
          settings,
          AuthGuard(
            allowedRoles: {UserRole.vendor},
            child: VendorAddProductScreen(
              existingProduct: args?.existingProduct,
            ),
          ),
        );
      case AppRoutes.vendorDashboard:
        return _materialRoute(
          settings,
          const AuthGuard(
            allowedRoles: {UserRole.vendor},
            child: VendorDashboardScreen(),
          ),
        );
      case AppRoutes.vendorProfile:
        final args = settings.arguments;
        if (args is! VendorProfileRouteArgs) return _errorRoute(settings);
        return _materialRoute(
          settings,
          VendorProfileScreen(vendorId: args.vendorId),
        );
      case AppRoutes.vendorProducts:
        return _materialRoute(
          settings,
          const AuthGuard(
            allowedRoles: {UserRole.vendor},
            child: VendorProductsScreen(),
          ),
        );
      case AppRoutes.vendorReviews:
        final args = settings.arguments;
        if (args is! VendorReviewsRouteArgs) return _errorRoute(settings);
        return _materialRoute(
          settings,
          VendorReviewsScreen(vendorId: args.vendorId),
        );
      case AppRoutes.vendorLicense:
        return _materialRoute(
          settings,
          const AuthGuard(
            allowedRoles: {UserRole.vendor},
            child: VendorLicenseScreen(),
          ),
        );
      case AppRoutes.recommendedIngredientStores:
        final args = settings.arguments;
        if (args is! RecommendedIngredientStoresRouteArgs) {
          return _errorRoute(settings);
        }
        return _slideRoute(
          settings,
          RecommendedIngredientStoresScreen(
            ingredientName: args.ingredientName,
            recipeTitle: args.recipeTitle,
          ),
        );
      default:
        return _errorRoute(settings);
    }
  }

  static MaterialPageRoute<dynamic> _materialRoute(
    RouteSettings settings,
    Widget child,
  ) {
    return MaterialPageRoute(settings: settings, builder: (_) => child);
  }

  static PageRouteBuilder<dynamic> _slideRoute(
    RouteSettings settings,
    Widget child,
  ) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, _, _) => child,
      transitionsBuilder: (_, animation, _, child) {
        final tween = Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
    );
  }

  static MaterialPageRoute<dynamic> _errorRoute(RouteSettings settings) {
    return _materialRoute(
      settings,
      const Scaffold(body: Center(child: Text('Route not found'))),
    );
  }
}
