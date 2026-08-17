# PalengkeGo Frontend Refactor Architecture And Execution Plan

Date: 2026-06-04

Latest status update: 2026-06-13

## Purpose

This document is the main architecture and execution guide for making PalengkeGo easier to maintain, easier to test, and safer to connect to real backend services later.

The app is still frontend-first. Do not add Firebase, Paymongo, production APIs, or secrets until the frontend boundaries are stable. The right work now is to make the code honest, typed, testable, and provider-driven while preserving the current customer and vendor user flows.

## Current Audit Baseline

Current verified checkpoint from 2026-06-13:

- `flutter analyze`: `No issues found`.
- `flutter test --coverage`: all tests passed, `73/73`.
- `flutter build apk --debug`: built `build/app/outputs/flutter-apk/app-debug.apk`.
- Basic Flutter CI exists at `.github/workflows/flutter-ci.yml`.
- QA pipeline documentation exists at `docs/QA_PIPELINE.md`.
- Backend source of truth exists at `docs/BACKEND_ARCHITECTURE.md`.
- Backend direction is hybrid Firebase + Supabase, not Firebase Data Connect.
- Android package identity has been updated to `com.palengkego.app`.
- `pubspec.lock` is no longer ignored and should be committed for reproducible CI.
- Cart, orders, preferences, search, favorites, notifications, vendor stall/orders, recipes, and market state have Riverpod/provider boundaries.
- High-risk checkout/address/payment route results now use typed results instead of raw route maps.
- Add-to-cart bottom sheet now accepts typed `VendorProduct` data instead of UI-level product maps.
- New checkout orders intentionally start as `pending` until the vendor accepts them.
- Vendor order action provider tests cover accept, reject, ready, and complete transitions.
- Auth guard widget tests cover logged-out and logged-in rendering.
- Router tests cover invalid route arguments and unknown routes.
- Some lower-risk mock/data conversion maps still exist in repositories/domain model serialization and are acceptable until backend adapters replace them.

## Non-Negotiable Refactor Rules

1. Preserve visible behavior unless a phase explicitly changes it.
2. Do not replace dynamic flows with static demo content.
3. Do not add production backend integrations yet.
4. Do not commit secrets, Firebase config files, Paymongo secret keys, or local `.env` files.
5. Prefer typed domain models over `Map<String, dynamic>` in app flow.
6. Keep UI widgets mostly display-only.
7. Keep side effects in pages, controllers, providers, or services, not in small display widgets.
8. Every phase must end with fresh verification.
9. Do not start the next phase if `flutter analyze` has issues.
10. Stage and commit carefully because the worktree has many modified and untracked files.

## Target Architecture

Each feature should move toward this shape:

```text
lib/features/<feature>/
  domain/        Plain Dart models, enums, value objects, pure business rules
  data/          Repository interfaces and mock/backend adapters
  application/   Riverpod providers, notifiers, controllers, use-case orchestration
  presentation/  Pages and widgets
```

Shared code should stay small:

```text
lib/core/
  config/        Environment and compile-time config values
  navigation/    Route names, route args, app router
  theme/         App-wide theme and visual tokens
  widgets/       Reusable widgets used by multiple features
  utils/         Focused helpers with no feature ownership
  services/      Temporary legacy services only during migration
```

## Layer Responsibilities

### Domain Layer

Domain code should:

- Contain no Flutter UI imports.
- Contain no `BuildContext`.
- Contain no navigation.
- Contain no snackbars, dialogs, or widget state.
- Use immutable models where possible.
- Use enums for finite state like order status, payment status, user role, and fulfillment method.
- Expose derived labels through getters or extensions, not repeated strings in screens.

Great domain code looks like this:

```dart
enum OrderStatus {
  pending,
  preparing,
  ready,
  completed,
  cancelled;

  String get label {
    return switch (this) {
      OrderStatus.pending => 'Pending',
      OrderStatus.preparing => 'Preparing',
      OrderStatus.ready => 'Ready',
      OrderStatus.completed => 'Completed',
      OrderStatus.cancelled => 'Cancelled',
    };
  }
}
```

Poor domain code looks like this:

```dart
final status = orderMap['status'] as String;
if (status == 'pending' || status == 'Pending' || status == 'PENDING') {
  // screen-specific behavior
}
```

### Data Layer

Data code should:

- Define repository interfaces.
- Hide mock data behind repositories.
- Return typed models, not raw maps.
- Be easy to replace with Firebase/API adapters later.
- Avoid UI concerns.

Great repository code looks like this:

```dart
abstract class MarketRepository {
  List<MarketVendor> getFeaturedVendors();
  List<MarketVendor> getVendorsByCategory(String category);
  List<MarketProduct> getProductsForVendor(String vendorId);
}
```

Poor repository code looks like this:

```dart
final vendors = MockDataService.featuredVendors;
final firstName = vendors[0]['name'];
```

inside a screen.

### Application Layer

Application code should:

- Expose state through Riverpod.
- Own feature-level orchestration.
- Keep screen code simpler.
- Allow tests to override repositories or services.
- Avoid direct UI details where possible.

Great application code looks like this:

```dart
final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MockMarketRepository();
});
```

For more complex mutable state, prefer a `Notifier` or `AsyncNotifier` instead of more global singletons.

Poor application code looks like this:

```dart
final globalCart = CartService();
```

used directly across pages and widgets.

### Presentation Layer

Presentation code should:

- Render UI.
- Collect user input.
- Call application-layer actions.
- Keep navigation in pages or route-aware controls.
- Split large pages into display widgets by user-visible sections.

Great presentation code looks like this:

```dart
CheckoutFooter(
  enabled: selectedItems.isNotEmpty,
  onPlaceOrder: _placeOrder,
)
```

Poor presentation code looks like this:

```dart
CheckoutFooter(
  onPlaceOrder: () {
    globalOrders.placeOrders(...);
    globalCart.removeSelectedItems();
    Navigator.of(context).push(...);
  },
)
```

inside a reusable footer widget.

## Global Quality Bar

Code is high quality when all of these are true:

- `flutter analyze` returns `No issues found`.
- `flutter test` passes.
- The changed feature has at least one meaningful unit, provider, repository, or widget test.
- No new raw `Map<String, dynamic>` is introduced for cross-screen app data.
- No new global singleton is introduced.
- No small display widget imports a global service.
- No domain or data file imports Flutter UI packages.
- No screen grows beyond about 350 lines unless there is a documented reason.
- No generated or mechanical formatting churn is mixed with feature changes.
- No user-visible text contains mojibake or broken encoding.
- Navigation arguments are typed when a route requires data.
- Mock behavior is clearly separated from future production adapters.

## Verification Commands

Use Flutter's bundled SDK on this machine when available:

```powershell
C:\Users\fragi\Music\flutter\bin\flutter.bat analyze
C:\Users\fragi\Music\flutter\bin\flutter.bat test
C:\Users\fragi\Music\flutter\bin\flutter.bat build apk --debug
```

Fallback commands if Flutter is on `PATH` and working:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Do not report `dart analyze` as authoritative for this Flutter app. The plain Dart install may not use the correct Flutter SDK and may produce misleading failures.

## Phase 1: Analyzer Cleanup

Status: Completed as of 2026-06-13.

### Goal

Make the codebase analyzer-clean again by removing deprecated API usage.

### Why This Comes First

The project docs require a zero-warning policy. Any later refactor is harder to trust if analyzer output is already noisy.

### Main Issue

Earlier audits found `deprecated_member_use` info issues for `withOpacity(...)`. Current verified state is analyzer-clean.

### Files To Inspect

Run this first:

```powershell
rg -n "withOpacity" lib
```

Known areas include:

- `lib/features/auth/presentation/pages/login_screen.dart`
- `lib/features/auth/presentation/pages/registration_screen.dart`
- `lib/features/cart/presentation/widgets/cart_item_card.dart`
- `lib/features/checkout/presentation/pages/add_credit_card_screen.dart`
- `lib/features/checkout/presentation/widgets/checkout_delivery_cards.dart`
- `lib/features/checkout/presentation/widgets/checkout_footer.dart`
- `lib/features/home/presentation/pages/home_screen.dart`
- `lib/features/onboarding/presentation/pages/onboarding_screen.dart`
- `lib/features/onboarding/presentation/pages/splash_screen.dart`
- `lib/features/orders/presentation/widgets/tracking_contact_cards.dart`
- `lib/features/orders/presentation/widgets/tracking_map_preview.dart`
- `lib/features/profile/presentation/pages/profile_screen.dart`
- `lib/features/profile/presentation/pages/security_settings_screen.dart`
- `lib/features/profile/presentation/pages/set_delivery_address_screen.dart`
- `lib/features/recipes/presentation/pages/cookbook_screen.dart`
- `lib/features/recipes/presentation/pages/recipe_details_screen.dart`
- `lib/features/recipes/presentation/pages/recipes_screen.dart`
- `lib/features/recipes/presentation/widgets/recipe_hero_card.dart`
- `lib/features/recipes/presentation/widgets/recipe_ingredients_list.dart`
- `lib/features/recipes/presentation/widgets/recipe_steps_list.dart`

### Execution Steps

- [x] Search for all deprecated calls:

```powershell
rg -n "withOpacity" lib
```

- [x] Replace each call mechanically:

```dart
color.withOpacity(0.12)
```

becomes:

```dart
color.withValues(alpha: 0.12)
```

- [x] Preserve the exact alpha value.
- [x] Do not change colors, spacing, widgets, or behavior during this phase.
- [x] Run analyzer.
- [x] Run tests.
- [ ] Commit only the analyzer cleanup files.

### Verification

```powershell
C:\Users\fragi\Music\flutter\bin\flutter.bat analyze
C:\Users\fragi\Music\flutter\bin\flutter.bat test
```

Expected:

```text
No issues found
All tests passed
```

### Quality Bar

This phase is great when:

- `rg -n "withOpacity" lib` returns no results.
- `flutter analyze` returns `No issues found`.
- `flutter test` passes.
- The diff contains only `withOpacity` to `withValues(alpha: ...)` changes.
- No UI layout or flow changes are mixed in.

This phase is not good enough when:

- Analyzer still has any issue.
- A screen was redesigned while doing mechanical cleanup.
- Alpha values changed accidentally.

## Phase 2: Cart State Decoupling

### Goal

Remove presentation coupling from `CartService` and make cart badge state provider-driven.

### Current Problem

`CartService` imports `main_screen.dart` so it can call `updateCartBadgeCount(itemCount)`. This makes a core service depend on a presentation page.

Current bad dependency:

```text
lib/core/services/cart_service.dart -> lib/features/main/presentation/pages/main_screen.dart
```

### Files To Inspect

- `lib/core/services/cart_service.dart`
- `lib/features/cart/application/cart_provider.dart`
- `lib/features/main/presentation/pages/main_screen.dart`
- `lib/core/widgets/app_bottom_nav_bar.dart`
- `test/services/cart_service_test.dart`
- `test/features/cart/application/cart_provider_test.dart`

### Target Direction

Cart badge count should be derived from cart state, not pushed manually from the service.

Great code looks like:

```dart
final cartServiceProvider = ChangeNotifierProvider<CartService>((ref) {
  return CartService();
});

final cartBadgeCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartServiceProvider);
  return cart.itemCount;
});
```

If `ChangeNotifierProvider` is unavailable in the installed Riverpod API, use a transitional `Notifier` or keep the existing `Provider` but make the UI listen directly without service-to-page imports.

### Execution Steps

- [ ] Read `main_screen.dart` and identify how the badge count is currently stored.
- [ ] Read `CartService._notifyAll()`.
- [ ] Add or adjust a provider for badge count.
- [ ] Remove the `main_screen.dart` import from `cart_service.dart`.
- [ ] Remove the `updateCartBadgeCount(itemCount)` call from `CartService`.
- [ ] Update the bottom navigation UI to read badge count from Riverpod or from the cart service listener owned by the UI.
- [ ] Update tests so cart item count behavior remains covered.
- [ ] Run focused tests.
- [ ] Run full tests and analyzer.

### Verification

```powershell
rg -n "updateCartBadgeCount|features/main/presentation/pages/main_screen.dart" lib/core lib/features/cart
C:\Users\fragi\Music\flutter\bin\flutter.bat analyze
C:\Users\fragi\Music\flutter\bin\flutter.bat test test/services/cart_service_test.dart test/features/cart/application/cart_provider_test.dart
C:\Users\fragi\Music\flutter\bin\flutter.bat test
```

Expected:

- No service-layer import of `main_screen.dart`.
- No `updateCartBadgeCount(...)` call from `CartService`.
- Cart tests pass.
- Full test suite passes.

### Quality Bar

This phase is great when:

- `CartService` only owns cart data and cart mutations.
- Cart badge rendering is owned by UI/application state.
- Adding, removing, selecting, and clearing cart items still updates the visible badge.
- Tests prove `itemCount` stays correct.
- No screen imports `globalCart` directly.

This phase is not good enough when:

- `CartService` still imports a presentation file.
- Badge count is duplicated in a second mutable global.
- UI updates depend on hidden side effects instead of state reads/listeners.

## Phase 3: Replace Legacy Global Service Access

### Goal

Move cart and order access away from global singleton variables and toward provider-owned state.

### Current Problem

The providers currently return global services:

```dart
final cartServiceProvider = Provider<CartService>((ref) {
  return globalCart;
});
```

This is useful as a transition step, but not a final architecture.

### Files To Inspect

- `lib/core/services/cart_service.dart`
- `lib/core/services/order_service.dart`
- `lib/features/cart/application/cart_provider.dart`
- `lib/features/orders/application/order_provider.dart`
- `lib/features/cart/presentation/pages/shopping_cart_screen.dart`
- `lib/features/checkout/presentation/pages/checkout_screen.dart`
- `lib/features/orders/presentation/pages/order_history_screen.dart`
- `lib/features/vendors/presentation/widgets/add_to_cart_bottom_sheet.dart`
- `test/features/cart/application/cart_provider_test.dart`
- `test/features/orders/application/order_provider_test.dart`

### Execution Steps

- [ ] Search current global usage:

```powershell
rg -n "globalCart|globalOrders" lib test
```

- [ ] Decide transitional strategy:
  - Short-term acceptable: keep globals only in provider files and tests.
  - Better: instantiate services inside providers.
  - Best: migrate mutable services to Riverpod `Notifier` or `AsyncNotifier`.

- [ ] For cart, prefer provider-owned service:

```dart
final cartServiceProvider = Provider<CartService>((ref) {
  return CartService();
});
```

- [ ] For tests, use `ProviderContainer` and provider overrides instead of global identity checks.
- [ ] Remove or mark `globalCart` and `globalOrders` as deprecated shims if they must temporarily remain.
- [ ] Update screens to use `ref.read(...)` for actions and `ref.watch(...)` or listeners for rebuilds.
- [ ] Remove direct imports of legacy services from widgets that only need domain models.

### Verification

```powershell
rg -n "globalCart|globalOrders" lib test
C:\Users\fragi\Music\flutter\bin\flutter.bat analyze
C:\Users\fragi\Music\flutter\bin\flutter.bat test test/features/cart/application/cart_provider_test.dart test/features/orders/application/order_provider_test.dart
C:\Users\fragi\Music\flutter\bin\flutter.bat test
```

Expected:

- No direct `globalCart` or `globalOrders` usage in presentation files.
- If globals remain, usage is limited to compatibility shims with comments.
- Provider tests no longer assert identity with globals unless this is explicitly documented as a temporary checkpoint.

### Quality Bar

This phase is great when:

- App state can be overridden in tests.
- No page or widget reaches around Riverpod to import a global.
- Service lifecycle is controlled by providers.
- Cart/order behavior remains identical for users.

This phase is not good enough when:

- The provider is just a cosmetic wrapper and all screens still know about globals.
- Tests depend on shared global state leaking across test cases.
- A new singleton is introduced to replace an old singleton.

## Phase 4: Typed Navigation And Route Completion

### Goal

Finish central route ownership so app navigation is predictable and future auth/deep-link work is easier.

### Current Problem

`AppRoutes` and `AppRouter` exist, but they only cover part of the app. Some screens still use `MaterialPageRoute` or custom direct pushes.

### Files To Inspect

- `lib/core/navigation/app_routes.dart`
- `lib/core/navigation/app_router.dart`
- `lib/features/orders/presentation/pages/order_history_screen.dart`
- `lib/features/orders/presentation/pages/order_details_screen.dart`
- `lib/features/vendors/presentation/pages/vendor_products_screen.dart`
- `lib/features/vendors/presentation/pages/vendor_add_product_screen.dart`
- all screens found by:

```powershell
rg -n "Navigator\.push|MaterialPageRoute|PageTransitions\.|pushNamed" lib
```

### Target Direction

Every common app destination should have:

- a route name in `AppRoutes`;
- a typed route args class if arguments are required;
- an `AppRouter.onGenerateRoute` case;
- tests or smoke coverage for critical routes.

Great route args look like:

```dart
class OrderDetailsRouteArgs {
  const OrderDetailsRouteArgs({required this.order});

  final MarketOrder order;
}
```

Poor route args look like:

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => OrderDetailsScreen(
    data: {
      'id': order.id,
      'status': order.status.label,
    },
  ),
));
```

### Execution Steps

- [ ] Search direct route usage.
- [ ] Add missing route constants for:
  - `orderDetails`
  - `profile`
  - `editProfile`
  - `securitySettings`
  - `notifications`
  - `recipes`
  - `recipeDetails`
  - `vendorDashboard`
  - `vendorOrders`
  - `vendorProducts`
  - `vendorAddProduct`
  - `vendorEarnings`
  - `vendorProfile`
  - `vendorOnboarding`
  - `vendorAccount`
  - `vendorAccountDetails`
  - `vendorHelpSupport`
  - `vendorNotifications`
  - `vendorStallSettings`
- [ ] Add route args classes only where data is needed.
- [ ] Add router cases in small feature groups.
- [ ] Migrate one feature group at a time.
- [ ] Keep custom transitions centralized in router or `page_transitions.dart`.
- [ ] Add route smoke tests for critical flows if practical.

### Verification

```powershell
rg -n "MaterialPageRoute|Navigator\.push\(" lib/features
C:\Users\fragi\Music\flutter\bin\flutter.bat analyze
C:\Users\fragi\Music\flutter\bin\flutter.bat test
```

Expected:

- Remaining direct route pushes are intentional and documented.
- AppRouter handles all common app destinations.
- Invalid route args return an error route instead of crashing.

### Quality Bar

This phase is great when:

- A developer can scan `AppRoutes` and understand the app's main navigation map.
- Every route requiring data has typed args.
- No screen constructs fake maps just to navigate.
- Routes fail gracefully when called with the wrong args.

This phase is not good enough when:

- The router exists but most screens ignore it.
- A route takes `dynamic` and casts deeply inside a screen.
- Feature-specific navigation rules are scattered across pages.

## Phase 5: Order And Checkout Model Hardening

### Goal

Make checkout, confirmation, order details, and tracking use truthful typed data.

### Current Status

Multi-vendor checkout now passes a full list of created orders to confirmation. Pickup tracking also passes `order.isPickup` from order history. Those are good improvements.

Remaining risk:

- Some order detail information may still be hardcoded, fabricated, or screen-local.
- Payment state, fees, delivery address, pickup location, and fulfillment metadata need better modeling before real backend/payment work.

### Files To Inspect

- `lib/core/services/order_service.dart`
- `lib/features/orders/domain/market_order.dart`
- `lib/features/orders/domain/order_line_item.dart`
- `lib/features/orders/domain/order_status.dart`
- `lib/features/checkout/presentation/pages/checkout_screen.dart`
- `lib/features/checkout/presentation/pages/order_confirmation_screen.dart`
- `lib/features/orders/presentation/pages/order_details_screen.dart`
- `lib/features/orders/presentation/pages/track_order_screen.dart`
- `test/services/order_service_test.dart`

### Target Domain Additions

Consider adding typed fields when the UI needs them:

```dart
enum FulfillmentMethod {
  delivery,
  pickup;
}

enum PaymentStatus {
  unpaid,
  pending,
  paid,
  failed,
  refunded;
}
```

Potential `MarketOrder` fields:

- `fulfillmentMethod`
- `paymentMethod`
- `paymentStatus`
- `deliveryAddress`
- `deliveryFee`
- `serviceFee`
- `pickupLocation`
- `estimatedReadyAt`
- `estimatedDeliveredAt`

Only add fields that current screens actually need. Do not overbuild.

### Execution Steps

- [ ] Audit `order_details_screen.dart` for hardcoded ETA, fees, addresses, and locations.
- [ ] List every order value shown on confirmation/details/tracking.
- [ ] Mark each value as:
  - real from `MarketOrder`;
  - derived from `MarketOrder`;
  - missing from model;
  - temporary display copy.
- [ ] Add missing model fields only for values the UI already shows.
- [ ] Update `OrderService.placeOrders(...)` to populate those fields from checkout state.
- [ ] Update confirmation/details/tracking to render from typed fields.
- [ ] Add tests for multi-vendor checkout order creation.
- [ ] Add tests for pickup vs delivery order metadata.

### Verification

```powershell
C:\Users\fragi\Music\flutter\bin\flutter.bat test test/services/order_service_test.dart
C:\Users\fragi\Music\flutter\bin\flutter.bat analyze
C:\Users\fragi\Music\flutter\bin\flutter.bat test
```

Manual verification:

- Add items from one vendor and place delivery order.
- Add items from multiple vendors and place delivery order.
- Place pickup order.
- Confirm each created order appears in order history.
- Confirm tracking uses pickup UI for pickup and delivery UI for delivery.
- Confirm order details do not show fake addresses or fake fees unless clearly marked as mock/demo data.

### Quality Bar

This phase is great when:

- Order details can be explained entirely from `MarketOrder` and related domain models.
- Multi-vendor order confirmation shows all created orders truthfully.
- Pickup and delivery flows branch from typed order data.
- Tests cover grouped order creation.
- No screen fabricates important order data silently.

This phase is not good enough when:

- Order details still build a fake map.
- Checkout removes cart items but confirmation hides some created orders.
- Pickup orders are tracked like delivery orders.
- Payment display says a method succeeded without model support.

## Phase 6: Profile, Address, And Preferences Boundary

### Goal

Move profile, delivery address, and payment preference state behind typed repositories/providers.

### Current Problem

Customer preferences still rely on shared service state. Address and payment method data moves through `Map<String, dynamic>` results in several places.

### Files To Inspect

- `lib/core/services/customer_preferences_service.dart`
- `lib/features/profile/domain/customer_profile.dart`
- `lib/features/profile/data/profile_repository.dart`
- `lib/features/profile/data/mock_profile_repository.dart`
- `lib/features/profile/application/profile_provider.dart`
- `lib/features/profile/presentation/pages/set_delivery_address_screen.dart`
- `lib/features/cart/presentation/pages/shopping_cart_screen.dart`
- `lib/features/checkout/presentation/pages/checkout_screen.dart`
- `lib/features/checkout/presentation/pages/payment_methods_screen.dart`
- `lib/features/checkout/presentation/pages/add_credit_card_screen.dart`

### Target Direction

Create typed values for address and payment selection.

Great code looks like:

```dart
class DeliveryAddress {
  const DeliveryAddress({
    required this.primaryAddress,
    required this.streetAddress,
    required this.notes,
  });

  final String primaryAddress;
  final String streetAddress;
  final String notes;

  String get displayLine {
    if (streetAddress.isEmpty) return primaryAddress;
    return '$primaryAddress, $streetAddress';
  }
}
```

Poor code looks like:

```dart
final result = await Navigator.of(context).pushNamed(...);
final address = result['address'] as String;
final notes = result['notes'] as String;
```

repeated across screens.

### Execution Steps

- [ ] Define typed address and payment selection models.
- [ ] Update route returns to return typed values instead of maps.
- [ ] Update cart and checkout to read from a shared provider/repository boundary.
- [ ] Keep mock behavior local and deterministic.
- [ ] Add tests for updating address and payment method.
- [ ] Confirm cart and checkout show the same selected address.

### Verification

```powershell
rg -n "Map<String, dynamic>" lib/features/cart lib/features/checkout lib/features/profile
C:\Users\fragi\Music\flutter\bin\flutter.bat analyze
C:\Users\fragi\Music\flutter\bin\flutter.bat test
```

Manual verification:

- Open cart.
- Change delivery address.
- Confirm cart subtitle updates.
- Go to checkout.
- Confirm checkout uses the same address.
- Change payment method.
- Confirm checkout reflects the selected method.

### Quality Bar

This phase is great when:

- Address data is typed from selection through checkout.
- Cart and checkout do not disagree about the selected address.
- Payment selection is typed and testable.
- No user-facing field is silently dropped when returning from a route.

This phase is not good enough when:

- Every screen still casts route results from `Map<String, dynamic>`.
- Address selection only changes local screen state.
- Checkout displays stale address or payment data.

## Phase 7: Vendor Feature Cleanup

### Goal

Make vendor flows ready for real backend data and reduce duplicate screen-local logic.

### Current Status

Vendor repository/provider files exist, but not every vendor screen is fully migrated. Some screens still keep local hardcoded product/order/profile data.

### Files To Inspect

- `lib/features/vendors/domain/vendor_profile.dart`
- `lib/features/vendors/domain/vendor_product.dart`
- `lib/features/vendors/domain/vendor_order_item.dart`
- `lib/features/vendors/domain/vendor_stall_product.dart`
- `lib/features/vendors/data/vendor_repository.dart`
- `lib/features/vendors/data/mock_vendor_repository.dart`
- `lib/features/vendors/application/vendor_provider.dart`
- `lib/features/vendors/presentation/pages/vendor_dashboard_screen.dart`
- `lib/features/vendors/presentation/pages/vendor_orders_screen.dart`
- `lib/features/vendors/presentation/pages/vendor_products_screen.dart`
- `lib/features/vendors/presentation/pages/vendor_profile_screen.dart`
- `lib/features/vendors/presentation/pages/vendor_onboarding_screen.dart`
- `lib/features/vendors/presentation/pages/vendor_add_product_screen.dart`
- `lib/features/vendors/presentation/widgets/add_to_cart_bottom_sheet.dart`

### Target Direction

Vendor screens should read vendor data from repository/provider boundaries.

Great vendor screen code looks like:

```dart
final productsAsync = ref.watch(vendorProductsProvider(vendorId));

return productsAsync.when(
  data: (products) => VendorProductGrid(products: products),
  loading: () => const CircularProgressIndicator(),
  error: (_, _) => const Text('Unable to load products'),
);
```

Poor vendor screen code looks like:

```dart
final List<VendorStallProduct> _products = [
  VendorStallProduct(name: 'Fresh Bangus', ...),
  VendorStallProduct(name: 'Whole Chicken', ...),
];
```

inside a page that should represent persistent vendor inventory.

### Execution Steps

- [ ] Choose one vendor screen at a time.
- [ ] Start with `vendor_products_screen.dart` because inventory is important and currently local.
- [ ] Add repository methods for product stock updates if the UI toggles stock.
- [ ] Add mock repository mutation behavior.
- [ ] Update provider to expose product list and stock update actions.
- [ ] Update screen to use provider state.
- [ ] Keep existing UI layout.
- [ ] Add tests for product list and stock toggle mutation.
- [ ] Repeat for dashboard, orders, profile, and onboarding only after product screen is stable.

### Verification

```powershell
C:\Users\fragi\Music\flutter\bin\flutter.bat analyze
C:\Users\fragi\Music\flutter\bin\flutter.bat test
```

Manual verification:

- Open vendor product list.
- Search products.
- Filter out-of-stock products.
- Toggle product stock.
- Navigate away and back.
- Confirm state behavior matches the intended mock lifecycle.

### Quality Bar

This phase is great when:

- Vendor inventory is not hardcoded in the screen.
- Stock toggles update a repository/provider boundary.
- Vendor product models are typed.
- UI remains visually unchanged unless intentionally improved.
- Tests prove the repository mutation behavior.

This phase is not good enough when:

- Vendor screen data is copied from mock data into page-local lists.
- Toggling stock only mutates a widget-local object.
- Vendor models duplicate market models without a clear reason.

## Phase 8: Split Large Screens

### Goal

Reduce maintenance risk by splitting large pages into focused pages plus display widgets.

### Largest Current Targets

- `lib/features/checkout/presentation/pages/order_confirmation_screen.dart`
- `lib/features/vendors/presentation/pages/vendor_profile_screen.dart`
- `lib/features/orders/presentation/pages/order_details_screen.dart`
- `lib/features/vendors/presentation/pages/vendor_notifications_screen.dart`
- `lib/features/auth/presentation/pages/registration_screen.dart`
- `lib/features/vendors/presentation/pages/vendor_help_support_screen.dart`
- `lib/features/recipes/presentation/pages/recipes_screen.dart`
- `lib/features/profile/presentation/pages/security_settings_screen.dart`
- `lib/features/auth/presentation/pages/login_screen.dart`
- `lib/features/notifications/presentation/pages/notifications_screen.dart`

### Splitting Rule

Split by user-visible sections, not arbitrary code chunks.

Great split:

```text
order_confirmation_screen.dart
order_confirmation_header.dart
order_confirmation_summary.dart
order_confirmation_order_card.dart
order_confirmation_actions.dart
```

Poor split:

```text
order_confirmation_part_1.dart
order_confirmation_part_2.dart
order_confirmation_helpers.dart
```

### Execution Steps

- [ ] Pick one large page.
- [ ] Identify its visible sections.
- [ ] Extract display-only widgets first.
- [ ] Keep state, navigation, snackbars, and order placement in the page initially.
- [ ] Pass typed data and callbacks into widgets.
- [ ] Add widget tests for extracted widgets when inputs are simple.
- [ ] Run analyzer and tests before splitting another page.

### Verification

```powershell
Get-ChildItem -Path lib -Recurse -Filter *.dart | ForEach-Object { $lines=(Get-Content $_.FullName | Measure-Object -Line).Lines; [PSCustomObject]@{Lines=$lines; Path=$_.FullName} } | Sort-Object Lines -Descending | Select-Object -First 20
C:\Users\fragi\Music\flutter\bin\flutter.bat analyze
C:\Users\fragi\Music\flutter\bin\flutter.bat test
```

Manual verification:

- Open the changed screen.
- Confirm layout, scroll, buttons, and navigation still work.
- Check mobile-width behavior.

### Quality Bar

This phase is great when:

- The page becomes easier to read.
- Extracted widgets are named after real UI sections.
- Extracted widgets do not import global services.
- The page owns orchestration and widgets render UI.
- Tests or manual checks confirm no visible flow broke.

This phase is not good enough when:

- Files are split but responsibilities are still tangled.
- A small widget performs navigation or mutates global state unexpectedly.
- The page remains over 500 lines after easy display sections were extracted.

## Phase 9: Auth And Profile Readiness

### Goal

Make auth/profile flows ready for Firebase Auth or another backend without adding that backend yet.

### Current Status

Auth and profile repositories exist, but login/register screens still need to be audited for how much behavior remains page-local.

### Files To Inspect

- `lib/features/auth/domain/app_user.dart`
- `lib/features/auth/data/auth_repository.dart`
- `lib/features/auth/data/mock_auth_repository.dart`
- `lib/features/auth/application/auth_provider.dart`
- `lib/features/auth/presentation/pages/login_screen.dart`
- `lib/features/auth/presentation/pages/registration_screen.dart`
- `lib/features/profile/domain/customer_profile.dart`
- `lib/features/profile/data/profile_repository.dart`
- `lib/features/profile/data/mock_profile_repository.dart`
- `lib/features/profile/application/profile_provider.dart`
- `lib/features/profile/presentation/pages/profile_screen.dart`
- `lib/features/profile/presentation/pages/edit_profile_screen.dart`

### Execution Steps

- [ ] Confirm login uses `AuthRepository.login(...)`.
- [ ] Confirm registration uses `AuthRepository.register(...)`.
- [ ] Confirm logout uses `AuthRepository.logout(...)`.
- [ ] Add validation tests for auth repository behavior.
- [ ] Keep social login buttons clearly mocked or disabled until real integration exists.
- [ ] Move profile edits through `ProfileRepository.updateProfile(...)`.
- [ ] Make profile screens read provider state instead of duplicated local values.

### Verification

```powershell
C:\Users\fragi\Music\flutter\bin\flutter.bat analyze
C:\Users\fragi\Music\flutter\bin\flutter.bat test
```

Manual verification:

- Login flow reaches main screen.
- Registration flow reaches main screen.
- Logout returns to login.
- Profile edit updates displayed profile data if mock persistence is intended.

### Quality Bar

This phase is great when:

- Auth screens call repository methods.
- Mock auth behavior is explicit and testable.
- Social login buttons do not pretend to be production integrations.
- Profile updates go through a repository/provider path.

This phase is not good enough when:

- Login succeeds because a page directly pushes main without repository involvement.
- Mock auth state cannot be overridden in tests.
- Profile screens display hardcoded data while repositories exist unused.

## Phase 10: Android Release Readiness

Status: Partially completed as of 2026-06-13.

### Goal

Prepare Android configuration for a real debug/beta/release pipeline.

### Current Problem

Android debug identity has been updated:

- namespace: `com.palengkego.app`
- applicationId: `com.palengkego.app`
- app label: `PalengkeGo`

Remaining release issue:

- release signing still needs a proper secret-backed signing setup before Play Store/internal testing release lanes.

### Files To Inspect

- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/example/palengkego/MainActivity.kt`
- `pubspec.yaml`
- `web/manifest.json`

### Execution Steps

- [x] Choose final package ID, currently `com.palengkego.app`.
- [x] Update Android namespace.
- [x] Update Android application ID.
- [ ] Move Kotlin package directory if needed.
- [x] Update `MainActivity.kt` package declaration if needed.
- [x] Update app label from `palengkego` to `PalengkeGo`.
- [ ] Configure release signing using local uncommitted signing files.
- [ ] Document release signing setup without committing secrets.
- [ ] Confirm `pubspec.yaml` versioning policy.
- [ ] Confirm launcher icons are final or document replacement.

### Verification

```powershell
C:\Users\fragi\Music\flutter\bin\flutter.bat analyze
C:\Users\fragi\Music\flutter\bin\flutter.bat test
C:\Users\fragi\Music\flutter\bin\flutter.bat build apk --debug
```

Expected:

- Debug APK builds.
- Package ID is `com.palengkego.app`.
- App label is production-appropriate.
- Release signing secrets are not committed.

### Quality Bar

This phase is great when:

- Android package identity is final.
- Debug APK builds consistently.
- Release signing is documented and secret-safe.
- Build instructions in README match actual commands.

This phase is not good enough when:

- App still ships as `com.example`.
- Release builds use debug signing without a clear reason.
- Signing files or passwords are committed.

## Phase 11: Documentation And Git Hygiene

Status: In progress as of 2026-06-13.

### Goal

Keep docs useful, current, and trackable.

### Current Issues

- `docs/AI_HANDOFF.md` has been reduced to a current pointer file.
- `.gitignore` still ignores most docs by default, but current source-of-truth docs are allowlisted.
- `pubspec.lock` is no longer ignored and should be committed.

### Files To Inspect

- `.gitignore`
- `README.md`
- `docs/AI_HANDOFF.md`
- `docs/REFACTOR_HANDOFF.md`
- `docs/ARCHITECTURE_REFACTOR.md`
- `docs/BACKEND_ARCHITECTURE.md`
- `docs/QA_PIPELINE.md`
- `docs/audit-findings-and-issues-to-address-2026-06-04.md`
- `pubspec.lock`

### Execution Steps

- [x] Update stale claims in `docs/AI_HANDOFF.md`.
- [x] Decide which docs should be tracked.
- [x] Allowlist current source-of-truth docs.
- [x] Stop ignoring `pubspec.lock` unless the team has a strong reason.
- [x] Update README to match current architecture and mocked integrations.
- [ ] Keep handoff docs factual and dated.

### Verification

```powershell
git status --short --untracked-files=all
rg -n "only confirms the first|hardcoded to false|withOpacity|pubspec.lock" docs README.md .gitignore
```

### Quality Bar

This phase is great when:

- Docs agree with current code.
- A new developer can follow the next work order without guessing.
- Important docs are not accidentally ignored.
- `pubspec.lock` policy is intentional.

This phase is not good enough when:

- Docs contain old bug reports for already-fixed behavior.
- A plan says "TODO" or "implement later" without exact next actions.
- Important handoff docs cannot be committed because of `.gitignore`.

## Phase 12: Final Hardening And Manual QA

### Goal

Confirm the app is ready for backend wiring or beta/demo packaging.

### Automated Verification

Run:

```powershell
C:\Users\fragi\Music\flutter\bin\flutter.bat clean
C:\Users\fragi\Music\flutter\bin\flutter.bat pub get
C:\Users\fragi\Music\flutter\bin\flutter.bat analyze
C:\Users\fragi\Music\flutter\bin\flutter.bat test
C:\Users\fragi\Music\flutter\bin\flutter.bat build apk --debug
```

Expected:

- `flutter analyze`: `No issues found`
- `flutter test`: all tests passed
- `flutter build apk --debug`: build succeeds

### Manual Customer Flow QA

Verify:

- Splash screen.
- Onboarding.
- Login.
- Registration.
- Main shell navigation.
- Market browse.
- Vendor profile.
- Add to cart.
- Cart quantity/select/delete.
- Delivery address selection.
- Checkout delivery.
- Checkout pickup.
- Payment method selection.
- Order confirmation.
- Order history.
- Order details.
- Tracking.
- Recipes.
- Cookbook/saved recipes.
- Profile edit.
- Security settings.

### Manual Vendor Flow QA

Verify:

- Vendor onboarding.
- Vendor dashboard.
- Vendor orders.
- Vendor products.
- Product stock toggle.
- Add product.
- Vendor earnings.
- Vendor profile.
- Vendor account.
- Vendor notifications.
- Help/support.
- Stall settings.

### Quality Bar

Final quality is great when:

- Automated checks pass.
- Debug APK builds.
- Manual customer and vendor flows complete without crashes.
- Mocked areas are clearly documented.
- No user-visible text is corrupted.
- No feature screen silently lies with fake data where typed data exists.
- The codebase is ready for backend adapters without another broad frontend cleanup first.

Final quality is not good enough when:

- Analyzer is noisy.
- Tests are skipped.
- APK build is unconfirmed.
- Vendor flows still depend on hardcoded screen-local business data.
- Payment/order state is too vague for real integration.

## Recommended Execution Order

1. Analyzer cleanup.
2. Cart badge/state decoupling.
3. Legacy global service access cleanup.
4. Typed navigation completion.
5. Order and checkout model hardening.
6. Profile/address/payment preference boundary.
7. Vendor feature cleanup.
8. Large screen splitting.
9. Auth/profile readiness.
10. Android release readiness.
11. Documentation and git hygiene.
12. Final hardening and manual QA.

## Commit Strategy

Use small commits by phase or feature group.

Good commit examples:

```text
chore: replace deprecated color opacity calls
refactor: decouple cart badge from cart service
refactor: centralize order detail routing
refactor: type checkout address selection
refactor: move vendor products behind repository
chore: configure android package identity
docs: update architecture refactor execution plan
```

Avoid:

```text
big update
fix stuff
final changes
```

## Stop Conditions

Stop and reassess if:

- `flutter analyze` is not clean after a phase.
- `flutter test` fails after a phase.
- A refactor requires visible UX changes not already approved.
- A production integration requires secrets.
- One phase touches more than six large page files before a verification gate.
- A screen becomes less dynamic than it was before the change.

## Final Definition Of Better

The codebase is meaningfully better when:

- App state flows through provider/repository boundaries.
- Domain models describe real app concepts instead of screen-local maps.
- Screens are readable and focused.
- Tests cover the important local business behavior.
- Analyzer output is clean.
- Android build readiness is verified.
- Docs match the code.
- Future backend work can plug into existing interfaces instead of rewriting screens.
