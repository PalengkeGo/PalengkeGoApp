# Changelog

All notable changes to the PalengkeGoAPP project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to Semantic Versioning.

## [Money Parity & E2E] — displayed total == charged total, provably

* **Centavo parity everywhere a customer pays:** new `core/utils/money.dart` (`centavosOf`/`pesoOf`/`roundToCentavos`) replicates the backend's single-round centavo math; all 14 pay-amount displays (cart, checkout, confirmation, order details/history, cancel dialog) format from the same rounded centavos the backend charges — the displayed-vs-charged centavo divergence class is closed. Unit-tested, including the classic `0.1 + 0.2` case.
* **Automated end-to-end money-path suite:** `npm run test:payments-e2e` boots the REAL firestore+auth+functions emulators with a stub PayMongo and drives the deployed code path: placeOrder (transactional pricing/stock) → createPaymentIntent (atomic claim, server-computed amount asserted against the stub) → signed segmented webhook → `paid`, plus unsigned-webhook rejection, redelivery idempotence, the failed-event downgrade guard, and the failed-payment path. Skipped in default `npm test` runs (gated by env).
* **Backend portability fix:** `PAYMONGO_API_URL` is env-overridable (emulator/E2E only; production unchanged), and all functions use explicit `firebase-admin/firestore` imports (`FieldValue`/`Timestamp`/`DocumentReference`) — the namespace-static form breaks under the functions emulator.

## [Payments Release] — the money path goes live

### Added
* **Payments — client wiring (audit H2):** `PayMongoService` now implements the documented intent flow — trusted `createPaymentIntent` callable, e-wallet payment-method creation and attach with the public key, redirect-URL extraction — and checkout initiates payment sessions for GCash/Maya orders with per-order status/retry UI on the confirmation screen. In-app card entry remains a documented follow-up (the app deliberately stores no card credentials).

### Fixed
* **Payments — webhook signature format (audit M1):** `verifyWebhookSignature` now parses PayMongo's documented segmented `Paymongo-Signature` header (`t=<unix seconds>,te=<test sig>,li=<live sig>`) and verifies HMAC-SHA256 over `<t>.<raw body>`, with a 5-minute replay window and constant-time compare. The legacy bare-hex header still verifies. Applied to both the Firebase Function and the Supabase edge port; both test suites cover the new format.
* **Payments — duplicate-intent race (audit M2):** `createPaymentIntent` atomically claims the order (`pending → processing`) in a transaction before calling PayMongo and releases the claim on failure, so concurrent calls can no longer create two Payment Intents.

## [1.0.1] — earnings screen serves real data

* The vendor earnings screen renders totals, period-over-period changes, and charts from the trusted `salesSummary` rollups (mock mode serves the seeded demo set). Zero sales show honest zeros — the hardcoded ₱2,450/₱12,450/₱48,200 figures are gone. Tests assert the computed values.

## [Security Hardening Sprint] — rules, transactions, refunds

### Fixed
* **Security — client-side order creation denied (audit H1):** `firestore.rules` no longer allows any client `create` on `orders`; the trusted `placeOrder` path (server-side prices/fees/stock) is the only way in. Rules tests updated.
* **Orders — transactional status transitions (audit H3):** `applyStatusTransition` (Firebase + Supabase) now reads, validates and writes inside ONE Firestore transaction — a concurrent cancel-vs-complete can no longer stamp illegal terminal states.
* **Orders — restock on cancellation (audit M4):** cancelling or rejecting an order atomically returns the deducted stock (`FieldValue.increment`) inside the same transaction.
* **Ratings rules hardened (08-21 audit S2):** the `ratings` create rule now binds the review's `vendorId` to the completed order's `stallId` (no cross-vendor attribution) and requires the deterministic `{orderId}_{uid}` doc id (document identity closes unlimited duplicates). Verified by three new rules tests.
* **Storage rules hardened (08-21 S5):** image paths accept images only (8 MB stalls / 5 MB profiles); KYC accepts images or PDF up to 15 MB — phishing-HTML hosting and storage-cost abuse are closed.
* **Refund settlement states (audit M5):** `createRefund` no longer marks the order `refunded` on a PayMongo `pending` refund; it records `refundPending` and lets the verified `payment.refunded` webhook perform the authoritative flip. New `PaymentStatus.refundPending` on the Flutter side.
* **Webhook idempotence:** a duplicate/delayed `payment.failed` can no longer downgrade an already `paid`/`refunded`/`refundPending` order (both webhook ports).
* **Stale payment-claim recovery:** `createPaymentIntent` re-claims a `processing` order when the claim is stale (>10 min) and no intent was stamped; when an intent exists it is retrieved from PayMongo first — silently-succeeded intents self-heal to `paid`, canceled ones allow a fresh intent, still-open ones are refused (no orphaned-payment risk). Pure decision logic (`claimDecision`) unit-tested.
* **Refund double-issue guard:** `createRefund` now claims `paid → refundPending` transactionally before calling PayMongo and releases the claim on failure — near-simultaneous owner+admin refunds cannot both proceed.
* **statusHistory read fix:** the rules read path now authorizes through the parent order (`get()`), so the order-history UI works in Firebase mode; owning-customer read + foreign-customer denial covered by rules tests.

## [Vendor Data Release] — reviews, deletion, real numbers

* Review reads go through the repository (`ratings` collection) in Firebase mode instead of `MockDataService` (audit M6); the rating modal no longer writes reviews under mock vendor ids in Firebase mode; the vendor profile section's review carousel serves repository data too.
* Product deletion is real and owner-scoped: `deleteVendorProduct` in Firebase mode deletes the actual `vendorStalls/{stallId}/products/{productId}` doc (rules enforce stall ownership; new rules test: cross-vendor delete denied). Previously it mutated mock state — deletion silently did nothing server-side.
* No fabricated trust signals: ingredient-recommendation cards show the platform's flat delivery fee (FeeConfig) and hide the delivery-time and "🔥 N+ orders" badges when there is no real data.
* Blocked stalls persist across restarts; the KYC theatrical 3-second delay runs only in demo mode.
* Admins may now advance stuck orders through the transition graph (audit M7); `estimatedReadyTime` is vendor/admin-only; `getSalesReport` rate-limits and honors App Check.

## [Team Process] — how we work, written down

* `TEAM_WORKFLOW.md` gains a "Clone, never download-and-re-upload" section documenting the disconnected-history incident and the rules (branch + PR only, lock-file conflict procedure, conflict-marker check) that prevent a repeat.
* `docs/TEST_CASES.md` — full manual/API/automated test-case catalog (payments incl. signed-webhook simulation, order lifecycle, refunds, reviews, security negative tests, concurrency races, performance budgets), with metrics, gates, and an audit-finding→test traceability matrix.
* `docs/audit-2026-08-22.md` — master audit with per-finding remediation status across four verification passes.

## [Cleanup] — deletion over addition (YAGNI pass)

* Deleted dead code: legacy `sales_report_screen.dart`, `back_button_widget.dart`, empty `core/models/`, no-op `clearOrders()`.
* Removed the duplicate `vendorReviewsProvider` family from `vendor_provider.dart` (zero callers; the repository-backed one is canonical) — the same-name collision hazard is gone.
* Stall resolution at checkout now fails loudly on ambiguous stall names instead of arbitrarily picking the first match.
* Release builds render a generic error widget instead of raw exception text; the payment-URL launcher is exception-safe.

## [Data Integrity] — concurrent carts, honest checkouts, unfrozen exports

* **Cart writes are transactional:** every cart mutation (add/update/toggle/select/remove) runs read+write inside ONE Firestore transaction via a shared `_mutate` helper — two devices on one account can no longer silently lose each other's writes.
* **Multi-vendor checkout no longer partially commits:** if a later vendor's order fails during placement, the already-placed orders are auto-cancelled (inside the 5-min window) and the customer gets an honest message; if compensation itself fails, the message says THAT too.
* **Exports run off the UI isolate:** PDF/Excel builds in both report screens are wrapped in `Isolate.run` — a month-sized report can no longer freeze the screen.
* **Tooling — pubspec.lock repair:** the committed lock file contained unresolved merge-conflict markers and broke `flutter pub get`; regenerated from the unchanged `pubspec.yaml`.

## [July 25, 2026]

### Refactored
* **Technical Debt & Static Analysis Cleanup:** Conducted a comprehensive static analysis audit across all feature packages.
* **Compiler & Lint Resolution:** Resolved all IDE warnings, updated stale Freezed generated model getters, and ensured clean `flutter analyze` compliance.
* **Code Maintenance:** Removed unused imports, obsolete helper methods, and dead code blocks from core services and presentation widgets.

## [July 20, 2026]

### Refactored
* **ERD Reconciliation:** Executed Entity-Relationship Diagram reconciliation (`backend_consolidation_check.md`) comparing schema specifications against the current codebase state.
* **Domain Model Unification:** Unified data models for `CustomerProfile`, `AppNotification`, and `MarketOrder` cancellation reasons across data and domain layers.
* **Backend Readiness:** Verified repository facade contracts (`mock_market_repository.dart`, `mock_auth_repository.dart`) to ensure data models map seamlessly when replacing mock layers with production REST/Firebase APIs.

## [July 17, 2026]

### Changed
* **UI/UX & Design Audit:** Conducted an interface design audit evaluating visual hierarchy, responsive layout behavior, and spacing consistency across mobile and web viewports.
* **Grid & Card Alignment:** Adjusted aspect ratios, padding, typography scale, and button tap targets in `VendorProfileProductCard` and market storefront grid views.

## [July 14, 2026]

### Refactored
* **Codebase Memory Graph Audit:** Performed deep dependency graph analysis across Riverpod providers and feature modules using codebase memory tools.
* **State Management Optimization:** Optimized provider invalidation callbacks, eliminated redundant state recalculations, and clean-up family provider bindings.

## [July 11, 2026]

### Added
* **Automated Log Parsing Tools:** Developed session transcript scraping scripts (`scrape_history.py`, `update_compiled_history.py`) to extract development history, format bug highlights, and maintain project records.
* **Documentation Artifacts:** Generated unified developer documentation (`DEVELOPER_DOCUMENTATION.md`) and compiled history tracking (`docs/archive/compiled_history.md`).

## [July 07, 2026]

### Added
* **Automated Store Operating Hours Override:** Implemented `VendorStallNotifier` background service evaluating stall schedules against local device time every 60 seconds to automatically toggle store `isOpen` status.
* **Closed Stall Product Filtering:** Updated `market_provider.dart` (`discountedProductsProvider`) to strictly exclude items of closed stalls from marketplace feeds and Flash Deals carousels.
* **Intelligent Recipe Recommendations:** Added item-based recommendation triggers in `notification_service.dart` (e.g. automatically recommending "Mango Sticky Rice" upon purchasing mangoes).
* **Notification Recipe Mini-Cards:** Integrated horizontal scrollable recipe mini-cards inside `notifications_screen.dart` with direct navigation to `RecipeDetailsScreen`.
* **Asynchronous KYC Processing Notifier:** Implemented global `KycProcessor` riverpod notifier in `lib/features/vendors/application/kyc_provider.dart`, ensuring vendor application verification timers survive widget disposal.
* **Role Upgrade Modal:** Added a delayed approval dialog on the home screen with a "Manage Stall" button promoting users from customer to vendor role.

### Fixed
* **Android File Picker V1 Embedding Build Error:** Resolved Gradle compilation failure (`error: cannot find symbol: io.flutter.plugin.common.PluginRegistry.Registrar`) by bumping `file_picker` dependency to `^8.1.4` (resolving to `8.3.7`).
* **Registration Validation Text Clipping:** Refactored text input fields in `registration_screen.dart` using standard `OutlineInputBorder` under `InputDecoration` to properly display validation error messages below fields.
* **Search Overlay Obstruction:** Added `isInline` flag to `SearchField` (`search_field.dart`) and set `isInline: true` in `market_screen.dart` to prevent redundant search dropdown overlays from blocking inline page filtering.
* **Asymmetrical Weight Steps:** Corrected quantity picker logic in `add_to_cart_bottom_sheet.dart` and `cart_item_card.dart` to use symmetric **0.25 kg** steps for weight-based produce (`unit == 'kg'`).
* **Splash Screen Layout Alignment:** Wrapped app title and tagline in `Center` widgets with explicit `textAlign: TextAlign.center` in `splash_screen.dart`.

## [July 06, 2026]

### Added
* **Adaptive Image Component:** Integrated `AdaptiveImage` across `VendorProfileProductCard`, `VendorProductsScreen`, `AddToCartBottomSheet`, and `DiscountedItemCard` to seamlessly render local device gallery images (`file://`) and network URLs (`http://`, `https://`).
* **Store Status Synchronization:** Synchronized real-time vendor open/close badges across customer market feeds and vendor profile screens.

## [June 30, 2026]

### Refactored
* **Agent Tooling & Workflow Configuration:** Audited agent skills repository and integrated core engineering skills into local Gemini configuration (`.gemini/config/skills`).

## [June 24, 2026]

### Added
* **Multiple Location Selection Sheet:** Created `LocationSelectionSheet` (FoodPanda-style bottom sheet) enabling switching between saved delivery addresses (Home, Work, School).
* **Address Verification Rule:** Enforced mandatory delivery location selection during account registration.

### Fixed
* **Weight Picker Category Unit Overwrite:** Resolved bug in `vendor_add_product_screen.dart` where category selection (Fruits/Vegetables) forced product units to `pcs`, overwriting `/kg` price formats.
* **Stock Unit Display Readout:** Fixed `UnitHelper.getUnitString` hardcode (`return 'kg';`) by adding `UnitHelper.isPieceProduct()` to parse price unit strings accurately.

## [June 23, 2026]

### Added
* **NotebookLM Knowledge Repository:** Created and initialized NotebookLM workspace repository, indexing core documentation (`ARCHITECTURE_REFACTOR.md`, `CODEBASE_GUIDE.md`, `DESIGN_SYSTEM.md`, `PRODUCT.md`, `README.md`).

## [June 18, 2026]

### Fixed
* **Vendor Block/Report Navigation Flow:** Fixed navigation bug in `block_vendor_dialog.dart` where blocking a stall from the Favorites tab executed `navigator.popUntil` back to home, prematurely closing `SavedStallsScreen`.
* **Notifications Banner Scroll Widening:** Fixed padding interpolation and layout overflow on `NotificationsScreen` status banner during scroll interactions.
* **Sticky Banner Border Radius:** Corrected reverse scroll animation math on sticky notification headers, locking `borderRadius: 24.0` for rounded edges.

## [June 14, 2026]

### Added
* **Saved & Blocked Stalls Screen:** Built `SavedStallsScreen` (`lib/features/vendors/presentation/pages/saved_stalls_screen.dart`) featuring an animated sliding pill tab toggle (`AnimatedPositioned`) between **Favorites** and **Blocked** stalls.
* **Blocked Vendor Data Provider:** Implemented `blockedVendorsListProvider` to map blocked vendor IDs back into full `MarketVendor` data objects.

### Fixed
* **Market Filter Category Mismatch:** Fixed product filtering bug where filtering by "Meat" omitted products under compound category strings (e.g. "Meat & Poultry"); updated comparison logic in `mock_market_repository.dart` to `.contains()`.
* **Family Provider Invalidation Crash:** Resolved post-product-creation crash caused by calling invalid `ref.invalidate(filteredVendorsProvider)` on a family provider.
* **ScaffoldMessenger Context Lookup Crash:** Fixed snackbar context lookup failure when popping screens after saving products.

## [May 30, 2026]

### Fixed
* **Product Card Layout Overflow & Unclickable Buttons:** Fixed `VendorProfileProductCard` image container height overflow where fixed heights (`126.75` / `110`) pushed the `+` button outside card tap boundaries. Replaced fixed height with `Expanded` layout and adjusted grid `childAspectRatio`.
* **Deactivated Widget Focus Crash:** Resolved `deactivated widget's ancestor is unsafe` layout crash in `VendorAddProductScreen` when switching category or image while `TextField` retained keyboard focus.
* **Prototyping Validation Bypass:** Softened strict form validation requirements during prototyping on login and registration screens, allowing blank form submissions to pass fallback dummy data.
* **State Synchronization Freeze:** Resolved Riverpod async state bug in `mock_auth_repository.dart` that caused infinite loading spinners on profile navigation.

## [May 29, 2026]

### Added
* **Domain Model Extraction:** Promoted private inline data classes to shared domain models under `lib/features/vendors/domain/`:
  * `vendor_order_item.dart` (promoted `_VendorOrder` from `vendor_orders_screen.dart`).
  * `vendor_stall_product.dart` (promoted `_VendorProduct` from `vendor_products_screen.dart`).
  * `day_schedule.dart` (promoted `DaySchedule` from `vendor_stall_settings_screen.dart`).

### Refactored
* **Stall Settings Screen Split:** Decoupled `vendor_stall_settings_screen.dart` (reduced file length from 869 to ~160 lines) into focused sub-widgets under `lib/features/vendors/presentation/widgets/`: `stall_photo_editor.dart`, `stall_info_form.dart`, `stall_operating_hours_picker.dart`, and `stall_danger_zone.dart`.
* **Vendor Products Screen Split:** Modularized `vendor_products_screen.dart` into `vendor_product_card.dart` and `vendor_product_filter_sheet.dart`.
* **Vendor Orders Screen Split:** Modularized `vendor_orders_screen.dart` into `vendor_order_card.dart` and `vendor_order_filter_bar.dart`.
* **Deprecation Upgrades:** Replaced deprecated `WillPopScope` with `PopScope` and replaced `.withOpacity()` calls with `.withAlpha()` across vendor presentation views.

## [May 27, 2026]

### Added
* **Saved Recipes / Cookbook Feature:** Designed and built the favorite-recipes repository feature.
* **Cookbook Provider:** Implemented `SavedRecipesNotifier` provider extending Riverpod's `Notifier` (`lib/features/recipes/application/saved_recipes_provider.dart`) managing favorite state persistence (`isSaved`, `toggleSave`).
* **Cookbook UI Screen:** Implemented `CookbookScreen` (`lib/features/recipes/presentation/pages/cookbook_screen.dart`) featuring list tiles, slide-to-remove actions, undo toasts, and an empty state illustration with an "Explore Recipes" call to action.
* **Vector Assets & Routing:** Added vector asset `cookbook.svg` (`assets/icons/cookbook.svg`) and registered `/cookbook` route path in `app_router.dart` and `app_routes.dart` with slide route transitions.
* **Automated Unit Tests:** Created unit test suite `test/features/recipes/saved_recipes_provider_test.dart` verifying favorite recipe state persistence and toggling.

### Changed
* **Recipe UI Integration:** Updated `recipes_screen.dart` and `recipe_details_screen.dart` to listen to `savedRecipesProvider` state and update heart icons dynamically.
