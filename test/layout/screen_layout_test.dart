import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/l10n/app_localizations.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/cart/application/cart_provider.dart';
import 'package:palengkego/features/cart/data/mock_cart_repository.dart';
import 'package:palengkego/features/cart/domain/cart_item.dart';
import 'package:palengkego/features/cart/presentation/pages/shopping_cart_screen.dart';
import 'package:palengkego/features/checkout/presentation/pages/checkout_screen.dart';
import 'package:palengkego/features/home/presentation/pages/home_screen.dart';
import 'package:palengkego/features/home/presentation/pages/market_screen.dart';
import 'package:palengkego/features/home/presentation/widgets/search_field.dart';
import 'package:palengkego/features/notifications/presentation/pages/notifications_screen.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = [
  Size(360, 740),
  Size(390, 844),
  Size(430, 932),
  Size(768, 1024),
];

Future<void> pumpAt(WidgetTester tester, Size size, Widget app) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
}

/// Unmounts the tree so repeating timers (carousel autoplay, stall schedule)
/// are cancelled before the test framework asserts none are pending.
Future<void> unmountTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform {}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.initialUser);

  final AppUser? initialUser;

  @override
  AppUser? build() => initialUser;
}

void main() {
  late MockCartRepository cartRepository;
  late SharedPreferences prefs;

  setUp(() async {
    FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    MockCartRepository.clearTestState();
    cartRepository = MockCartRepository()
      ..addToCart(
        const CartItem(
          productId: 'm1',
          vendorName: 'Diosa Fruit Stand',
          productName: 'Sweet Mangoes',
          price: 150,
          unit: 'kg',
          image: 'https://example.com/mango.jpg',
        ),
      );
  });

  Widget wrap(Widget screen, {AppUser? user, bool seedCart = false}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => _TestAuthNotifier(user)),
        if (seedCart) cartRepositoryProvider.overrideWithValue(cartRepository),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    );
  }

  for (final size in _sizes) {
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('home screen renders without exceptions', (tester) async {
        await pumpAt(tester, size, wrap(HomeScreen(onMarketSelected: () {})));
        expect(tester.takeException(), isNull);
        expect(find.byType(SearchField), findsOneWidget);
        await unmountTree(tester);
      });

      testWidgets('market screen renders without exceptions', (tester) async {
        await pumpAt(tester, size, wrap(const MarketScreen()));
        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsWidgets);
        await unmountTree(tester);
      });

      testWidgets('cart screen renders without exceptions', (tester) async {
        await pumpAt(
          tester,
          size,
          wrap(const ShoppingCartScreen(), seedCart: true),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Sweet Mangoes'), findsOneWidget);
        expect(find.text('Checkout'), findsOneWidget);
        await unmountTree(tester);
      });

      testWidgets('checkout screen renders without exceptions', (tester) async {
        await pumpAt(
          tester,
          size,
          wrap(
            const CheckoutScreen(),
            user: MockUsers.customer,
            seedCart: true,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Sweet Mangoes'), findsOneWidget);
        await unmountTree(tester);
      });

      testWidgets('notifications screen renders without exceptions', (
        tester,
      ) async {
        await pumpAt(tester, size, wrap(const NotificationsScreen()));
        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsOneWidget);
        await unmountTree(tester);
      });

      testWidgets('vendor dashboard renders without exceptions', (
        tester,
      ) async {
        await pumpAt(
          tester,
          size,
          wrap(const VendorDashboardScreen(), user: MockUsers.vendor),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsOneWidget);
        await unmountTree(tester);
      });

      testWidgets('home screen holds at 1.3x text scale without exceptions', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpAt(tester, size, wrap(HomeScreen(onMarketSelected: () {})));
        expect(tester.takeException(), isNull);
        await unmountTree(tester);
      });

      testWidgets('home screen holds at 1.5x text scale without exceptions', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpAt(tester, size, wrap(HomeScreen(onMarketSelected: () {})));
        expect(tester.takeException(), isNull);
        await unmountTree(tester);
      });
    });
  }

  final screens = <String, Widget Function()>{
    'home screen': () => wrap(HomeScreen(onMarketSelected: () {})),
    'market screen': () => wrap(const MarketScreen()),
    'cart screen': () => wrap(const ShoppingCartScreen(), seedCart: true),
    'checkout screen': () =>
        wrap(const CheckoutScreen(), user: MockUsers.customer, seedCart: true),
    'notifications screen': () => wrap(const NotificationsScreen()),
    'vendor dashboard': () =>
        wrap(const VendorDashboardScreen(), user: MockUsers.vendor),
  };

  for (final scale in const [1.3, 1.5]) {
    for (final size in const [Size(360, 740), Size(390, 844)]) {
      group('text scale ${scale}x at ${size.width.toInt()}dp', () {
        for (final entry in screens.entries) {
          testWidgets('${entry.key} renders without exceptions', (
            tester,
          ) async {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await pumpAt(tester, size, entry.value());
            final ex = tester.takeException();
            if (ex != null) {
              // ignore: avoid_print
              print(ex is FlutterError ? ex.toStringDeep() : ex.toString());
            }
            expect(ex, isNull);
            await unmountTree(tester);
          });
        }
      });
    }
  }
}
