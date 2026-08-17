# Changelog

All notable changes to the PalengkeGoAPP project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to Semantic Versioning.

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
