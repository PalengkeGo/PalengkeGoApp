import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/navigation/app_router.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/features/cart/presentation/pages/shopping_cart_screen.dart';
import 'package:palengkego/features/checkout/presentation/pages/checkout_screen.dart';
import 'package:palengkego/features/main/presentation/pages/main_screen.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/core/services/notification_service.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:palengkego/features/orders/domain/fulfillment_method.dart';
import 'package:palengkego/features/orders/domain/market_order.dart';
import 'package:palengkego/features/orders/domain/order_line_item.dart';
import 'package:palengkego/features/orders/domain/order_status.dart';
import 'package:palengkego/features/orders/domain/payment_status.dart';
import 'package:palengkego/features/orders/presentation/pages/order_details_screen.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildRoutedApp(
    String routeName, {
    Object? arguments,
    AppUser? user = MockUsers.customer,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith(() => _TestAuthNotifier(user)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWith(
          (ref) => NotificationService(isTest: true),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: routeName,
        routes: {routeName: (_) => const SizedBox.shrink()},
        onGenerateInitialRoutes: (initialRoute) {
          return [
            AppRouter.onGenerateRoute(
              RouteSettings(name: initialRoute, arguments: arguments),
            ),
          ];
        },
      ),
    );
  }

  group('AppRouter invalid route arguments', () {
    testWidgets('shows error route for order confirmation without typed args', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildRoutedApp(AppRoutes.orderConfirmation, arguments: 'bad-args'),
      );

      expect(find.text('Route not found'), findsOneWidget);
    });

    testWidgets('shows error route for track order without typed args', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildRoutedApp(AppRoutes.trackOrder, arguments: {'order': 'bad'}),
      );

      expect(find.text('Route not found'), findsOneWidget);
    });

    testWidgets('shows error route for order details without typed args', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildRoutedApp(AppRoutes.orderDetails, arguments: 123),
      );

      expect(find.text('Route not found'), findsOneWidget);
    });

    testWidgets('shows error route for unknown route name', (tester) async {
      await tester.pumpWidget(buildRoutedApp('/missing-route'));

      expect(find.text('Route not found'), findsOneWidget);
    });
  });

  group('AppRouter order tracking', () {
    testWidgets('track order route opens the canonical order details screen', (
      tester,
    ) async {
      final order = MarketOrder(
        id: '#test',
        vendorName: 'Diosa Fruit Stand',
        vendorImage: '',
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
        fulfillmentMethod: FulfillmentMethod.delivery,
        placedAt: DateTime.now(),
        deliveryFee: 49,
        serviceFee: 15,
        items: const [
          OrderLineItem(
            productId: 'p1',
            productName: 'Mango',
            quantity: 1,
            unitPrice: 100,
            image: '',
          ),
        ],
      );

      await tester.pumpWidget(
        buildRoutedApp(
          AppRoutes.trackOrder,
          arguments: TrackOrderRouteArgs(order: order, isPickup: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailsScreen), findsOneWidget);
      expect(find.text('Stall Holder Confirmation'), findsOneWidget);
    });
  });

  group('AppRouter guest browsing access', () {
    testWidgets('main route is browsable without login', (tester) async {
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception is NetworkImageLoadException) return;
        previousOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousOnError);

      await tester.pumpWidget(buildRoutedApp(AppRoutes.main, user: null));
      await tester.pump();

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.text('Account Required'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('cart route is browsable without login', (tester) async {
      await tester.pumpWidget(buildRoutedApp(AppRoutes.cart, user: null));
      await tester.pumpAndSettle();

      expect(find.byType(ShoppingCartScreen), findsOneWidget);
      expect(find.text('Shopping Cart'), findsOneWidget);
      expect(find.text('Account Required'), findsNothing);
    });

    testWidgets('checkout route still requires login', (tester) async {
      await tester.pumpWidget(buildRoutedApp(AppRoutes.checkout, user: null));
      await tester.pumpAndSettle();

      expect(find.byType(AuthGuard), findsOneWidget);
      expect(find.byType(CheckoutScreen), findsNothing);
      expect(find.text('Account Required'), findsOneWidget);
    });
  });

  group('AppRouter vendor route protection', () {
    testWidgets('vendor dashboard requires login', (tester) async {
      await tester.pumpWidget(
        buildRoutedApp(AppRoutes.vendorDashboard, user: null),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AuthGuard), findsOneWidget);
      expect(find.text('Account Required'), findsOneWidget);
      expect(find.byType(VendorDashboardScreen), findsNothing);
    });

    testWidgets('vendor dashboard rejects customer users', (tester) async {
      await tester.pumpWidget(
        buildRoutedApp(AppRoutes.vendorDashboard, user: MockUsers.customer),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AuthGuard), findsOneWidget);
      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.byType(VendorDashboardScreen), findsNothing);
    });

    testWidgets('vendor dashboard opens for vendor users', (tester) async {
      await tester.pumpWidget(
        buildRoutedApp(AppRoutes.vendorDashboard, user: MockUsers.vendor),
      );
      // The dashboard hosts an auto-ticking reviews carousel, so bounded
      // pumps are used instead of pumpAndSettle (which would time out).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(VendorDashboardScreen), findsOneWidget);
      expect(find.text('Account Required'), findsNothing);
      expect(find.text('Access Restricted'), findsNothing);
    });
  });
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.initialUser);

  final AppUser? initialUser;

  @override
  AppUser? build() {
    return initialUser;
  }
}
