# Changelog

All notable changes to the PalengkeGoAPP project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to Semantic Versioning.

## [September 02, 2026] — System Notifications, UX Fixes & Core Architecture Decoupling

### Added
* **Real System-Tray / Heads-Up Notifications ("Ready for Pick-Up" & "Out for Delivery"):** Configured `POST_NOTIFICATIONS` permission in `AndroidManifest.xml` (Android 13+) and set up high-priority `palengkego_order_updates` notification channel in `notification_service.dart`. Connected `OrderStatus.ready` ("Ready for pick-up!") and `OrderStatus.outForDelivery` ("Out for delivery!") to fire native OS notifications outside the app with vibration and banners.
* **Vendor Order Dispatch Flow:** Added `markOrderOutForDelivery` in `vendor_orders_provider.dart` and wired a "Dispatch for Delivery" action button in `vendor_orders_screen.dart` with robust status badge mapping in `order_details_timeline.dart`.
* **Admin Web Portal (Palengke Admin - MEPO) Tripartite Architecture:** Fully consolidated backend contracts connecting Customer App, Vendor App, and the Admin Web Portal (`Palengke Admin`). Documented administrative operations for vendor KYC document verification (private `kyc` bucket signed URLs), annual license renewal approvals, market section/floor/stall allocations, market surveillance reporting, system-wide announcements, and user account quarantine.
* **Admin Audit Trail (`adminActions`):** Added schema and access boundaries for immutable admin decision tracking (`kyc.approved`, `kyc.rejected`, `renewal.approved`, `renewal.rejected`, `account.blocked`, `account.unblocked`) written strictly via Admin SDK callables.
* **Production Firebase Android Build Credentials:** Integrated production `palengkegodb` credentials into `android/app/google-services.json` and synchronized `lib/firebase_options.dart`, resolving Android Gradle `processDebugGoogleServices` build failures for local debug APK builds.

### Changed & Fixed
* **Vendor Home Stall Settings Navigation:** Clicking the stall module/header in the Vendor Home UI now navigates directly to the Stall Settings screen (`VendorStallSettingsScreen`).
* **Checkout Currency Display Bug:** Fixed currency symbol duplication (`₱₱`) across order totals, subtotal summaries, and line items on the checkout screen (`checkout_screen.dart`).
* **Payment Methods Credit/Debit Lockout:** Disabled direct selection of the Credit/Debit Card module on the Payment Methods screen and integrated an informative "Coming Soon" notification, matching checkout behavior.
* **Track Order Delivery Priority Tag Bug:** Fixed standard delivery orders erroneously rendering a "Priority" badge at the top of the customer Track Order screen; aligned track order screen delivery badges directly with vendor stallholder order status.
* **Bottom Navigation Hit-Target Expansion:** Widened tap response boundaries on the bottom navigation bar icons (`AppBottomNavBar`) to evenly utilize whitespace between icons, preventing pixel-precision missed touches.
* **Order Tracker Destination Indicator:** Refined the active destination step in `OrderDetailsTimeline` to render an animated outline circle without premature green fill, preserving visual distinction until the step is actually completed.
* **Floating SnackBar Layout Stabilization:** Resolved off-screen layout exceptions thrown by floating SnackBars during state transitions and rapid route pops.
* **Order Timeline Status Crash Fix:** Added safe rank mappings in `OrderDetailsTimeline` for `outForDelivery` and `rejected` statuses to prevent null-check exceptions when viewing terminal or in-transit orders.

### Refactored
* **Architectural Decoupling & Circular Import Elimination (23-File Knot Broken):** Extracted all route argument classes (`VendorReviewsRouteArgs`, `MainRouteArgs`, `TrackOrderRouteArgs`, etc.) out of `app_router.dart` into a dedicated leaf [route_args.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/core/navigation/route_args.dart) and tab navigation into [main_tab_navigation.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/core/navigation/main_tab_navigation.dart). Decoupled 14 UI screens/widgets across checkout, home, orders, vendors, and recipes from `app_router.dart`, reducing circular import cycles across the entire application to 0.
* **Service Consolidation (`order_service.dart` ↔ `order_provider.dart`):** Moved `OrderService` `AsyncNotifier` into [order_provider.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/features/orders/application/order_provider.dart) with clean backward-compatible export from `core/services/order_service.dart`, breaking the mutual dependency between `core/` and `features/orders/`.
* **Storage Optimization & Cache Pruning:** Safely removed web build artifacts and cleaned obsolete global Gradle caches (`~/.gradle/caches` and `~/.gradle/daemon`), reclaiming 6.67 GB of disk space while preserving project build outputs and code-generation models.
* **Triple-Checked ERD & Backend Consolidation:** Reconciled `codebase_erd.md` and `backend_consolidation_check.md` against current active codebase state. Documented complete refund lifecycle (`requestRefund`, `processRefund`, `createRefund`, partial refund accumulation), recipe dynamic energy & substitute models, 6 composite indexes in `firestore.indexes.json`, Supabase storage bucket limits (`20260823000000_storage_buckets.sql`), and trusted-path-only Firestore security rules.

## [August 29, 2026] — UX & Recipe Feature Batch

### Changed
* **Login prompts at first add-to-cart:** a signed-out user who adds their very first item is prompted to log in (instead of at checkout); the item still saves to the device cart and merges on next login (`CartNotifier.addFirstItemPromptingLogin`, `add_to_cart_bottom_sheet.dart`).
* **Dynamic recipe energy:** calories are computed from per-ingredient `calorie` values (and chosen substitutes) via `Recipe.energyLabel`; the stats chip reflects substitutions live (`recipe.dart`, `recipe_stats_row.dart`).
* **Ingredient substitutes:** ticking an ingredient that offers substitutes opens a chooser (use one or keep the original); the chosen substitute updates energy and shows an "Using X instead" indicator. Data model (`RecipeSubstitute`) serializes to the recipe JSON; seeded in the mock repository (`recipe_substitute_sheet.dart`, `mock_recipe_repository.dart`).
* **Home header greeting:** the location indicator is replaced by a time-aware Good morning/afternoon/evening greeting (`home_header.dart`); location stays on the profile screen.
* **Tracking timeline:** only the furthest-advanced "done" circle shows a check; earlier completed circles fill green with no check (`order_details_timeline.dart`).
* **Vendor sees delivery mode:** order cards show Pick-Up / Standard Delivery / Priority Delivery, with the PRIORITY pill for priority orders (`vendor_orders_screen.dart`, `dashboard_recent_order_card.dart`, `dashboard_home.dart`).
* **Card payments marked Coming soon:** the credit/debit card option now shows a "Coming soon" badge and tapping it explains that card payments aren't available yet (GCash/PayMaya/cash stay enabled) (`payment_methods_screen.dart`).
* **"Flash Deals" renamed to "Special Offers"** in the home section header, the notification channel, and the discount notification title.
* **Image picker:** the "File" option is removed from picture-source sheets — only Gallery and Camera remain (`image_picker_helper.dart`).
* **Opening hours "apply to all":** after editing ANY single day, the app asks whether to apply that day's schedule to all other days (replaces the old Monday-only button) (`operating_hours_editor.dart`, `vendor_stall_settings_screen.dart`).
* **Renewal history detail popup:** tapping a renewal history row shows the renewal date, approval date, valid-for period, and fee paid (`vendor_license_history_list.dart`).
* **Renewal-approved success overlay:** a full-screen white overlay with a large checkmark and a Done button appears once a renewal is approved (`vendor_license_screen.dart`).
* **Dynamic & animated review diagram:** tapping a star row filters the distribution diagram and review list to that star (animated bars + crossfade); tapping again restores all (`vendor_review_summary_card.dart`, `vendor_reviews_screen.dart`).

### Added
* **Google Maps scaffold** for the delivery tracker — `lib/features/tracking/google_maps_scaffold.dart`: a `TrackingLocationService` abstraction (permission + position stream), mock service, and a placeholder map surface with a "Maps coming soon — not configured" state. No new dependencies; `geolocator` is already present. TODO(maps) notes mark where to wire `google_maps_flutter`.
* **Refunds surface in vendor notifications + customer history:** a `refund` notification type + `onRefundRequested` mirror the order-status flow, fired from `OrderService.requestRefund`; refunded/refund-requested orders show a status pill in the customer order history (`notification_service.dart`, `order_service.dart`, `order_history_card.dart`).

## [August 29, 2026]

### Fixed
* **Vendor Self-Approval Bypass (audit H1):** Hardened `vendorStalls` Firestore rules to deny client writes to privileged fields (`isKYCApproved`, `kycStatus`, `licenseStatus`, `licenseExpiryDate`, `averageRating`, `totalRatings`, `stallNumber`, `floorNumber`, `section`) — now written only by the trusted callables (`approveKyc`, `approveRenewal`, `addReview` aggregate) via Admin SDK. The client `updateVendorStall` strips server-owned fields before writing.
* **Vendor Earnings Read Permission Gap (audit H2):** Fixed Firestore rules to grant reads on the real `salesSummary/{stallId}/daily/{date}` path (the rules previously guarded a non-existent subcollection path, so vendor earnings screens would get `permission-denied` in production).
* **Client-Side Order Status Bypass (audit H3):** Removed the client `orders` update rule entirely — all order mutations now flow through the trusted callables (state machine, audit log, restock).
* **KYC Onboarding Dead End (audit H4):** Customer accounts can now submit KYC (`kycSubmissions` create: own identity, `pending` only, no pre-stamped review fields); `approveKyc` is the single atomic moment that promotes the role AND creates the stall doc; `approveRenewal` guards against a missing stall doc.
* **Unverified Emails Could Place Orders (audit M1):** `placeOrder` now rejects unverified emails, matching the Supabase port that already had it.
* **Client-Side Rating Bypass (audit M2):** Removed the client `ratings` create rule — reviews flow through `addReview` only (stall aggregate recomputed in the same transaction).
* **Negative Price/Stock Creation (audit M3):** Product create/update rules now require `price >= 0` and `stockQuantity >= 0`.
* **Blocked Users Could Still Write (audit M4):** Rules now apply `unblocked()` to stall/product/KYC/license writes, **and `addReview` now refuses blocked users on both backends** — the last missing piece, found and fixed during execution of the audit.
* **Sales Rollup Timezone Drift (audit L1):** Daily rollups now bucket by `Asia/Manila` date in both backends, matching what the client reads.
* **Report Date Boundary (audit L2):** `getSalesReport` date-only `to` is now end-of-day inclusive, and the range is capped at 366 days.
* **Refund Edge Cases (audit M5):** Stale `refundPending` recovery (asks PayMongo what happened), partial-refund awareness (`refundedAmount`/`refundIds`, `full|partial` outcome), and an amount cross-check on `payment.paid` webhooks.

### Added
* **Composite Indexes (audit M7):** `firestore.indexes.json` with the six composite indexes the queries need (orders, ratings, kycSubmissions, licenseRenewals).
* **Supabase Storage Buckets (audit M6):** Migration `20260823000000_storage_buckets.sql` — stalls/profiles (public), kyc/license (private), with size/MIME limits and anon insert/select RLS.
* **Rules Test Coverage:** Positive owner-read assertion for salesSummary (how the H2 gap survived 5 prior audits), plus new denial tests for H1/H3/H4, M3, M4, KYC/license submission blocks, and blocked-account behavior.
* **Refund Logic Unit Tests:** 8 new tests for `refundClaimDecision` / `refundOutcome` / `settledRefundCents`.
* **Payments e2e fixture fix:** e2e money-path users are now created with `emailVerified: true` in the Auth emulator (mirrors production email-verified customers), so the M1 gate is exercised on the live money path.

### Changed
* Removed the `firebase_storage` dependency and `firebaseStorageProvider` (zero readers — the Supabase Storage pivot is already done).
* `submitAndProcess` (KYC) no longer flips a local "vendor" flag in Firebase mode — it now honestly reports "application under review"; the vendor state arrives from the role upgrade after `approveKyc`.
* **Deploy order matters:** deploy `firestore:rules` + `firestore:indexes` before `functions`. Behavior changes: `placeOrder` rejects unverified emails; `approveKyc` can now approve a pending submission for a stall holder with no stall doc (previously crashed); `addReview` refuses blocked users.

### Refactored
* Shared `isBlocked` helper in `functions/src/security.ts` (dedupes the orders.ts copy).

### Added (refund flow — customer requests, vendor/admin processes)
* **`requestRefund` callable:** a customer who owns a `paid` order can request a refund. It moves no money — it records the reason and flips `paymentStatus: paid → refundRequested` for a vendor/admin to resolve.
* **`processRefund` callable:** a stall owner or admin approves (runs the PayMongo refund money path) or declines (order returns to `paid`) a refund request. Shares the single money path with `createRefund` via a refactored `performRefund` helper.
* **Customer refund UI:** a "Request a refund" action on the paid order's details opens a bottom sheet (reason chips + optional note + refundable-amount summary); inline status banners show "Refund requested", "Refund in progress", "Refunded", or "Partially refunded".
* **Vendor refund UI:** a refund-request card on the vendor order details screen shows the customer's reason with explicit **Approve refund / Decline** actions (and a confirmation dialog).
* **Truthful payment display:** `OrderDetailsPaymentCard` now shows the order's real payment method (was hard-coded "Cash on Delivery") and the returned refunded amount.
* **Payment entry polish:** the Add Card screen got a live brand/masked-number preview, theme-aligned surfaces, a keyboard-aware Save bar, and refined validation hierarchy.
* **Refund flow tests:** 5 new unit tests locking the mock repo lifecycle (paid → refundRequested → refunded | paid).

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
