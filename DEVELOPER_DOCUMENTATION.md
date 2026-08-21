# PalengkeGoAPP - Development Progress & Bug History Tracker

This document provides a comprehensive, professional, chronological track of PalengkeGoAPP's engineering progress, core features, architecture, and detailed bug documentation compiled across development sessions.

## 1. Project Overview

**PalengkeGoAPP** is a specialized Flutter-based mobile and web application designed to digitize local traditional markets (wet markets). It bridges the gap between stall holders (vendors) and consumers by offering:
* **For Consumers:** Vendor stall browsing, search and category filtering, cart management, flexible pickup/delivery checkout configurations, and recipe recommendations synced with cart purchases.
* **For Vendors:** An onboarding/KYC pipeline, inventory management, dynamic operating schedules with background sync overrides, order status dispatching, and vendor notifications.

## 2. Architecture & Tech Stack

* **Core Framework:** Flutter (Android, iOS, Web compatibility).
* **State Management:** Riverpod 2.x (highly reactive layout data-binding via `NotifierProvider`, family invalidation logic, and scoped state trackers).
* **Routing:** GoRouter (centralized declarative navigation tree).
* **Data Modeling:** Freezed and JSON Serializable for safe, compile-time immutable models.
* **Data Layer Isolation:** Clean Feature-First Domain-Driven Design (DDD) layout. Core UI screens are decoupled from data services using Repository Facades (e.g. `mock_market_repository.dart`) containing network delay latency models to insulate the frontend during prototyping.

## 3. Chronological Progress Track & Feature Evolution

### 📅 Session: Saved Recipes Cookbook Feature & Automated Testing
* **Date:** May 26, 2026
* **Session ID:** `a504c9a5-b44f-493c-b978-407f75a8b43c`

#### 🛠️ Implemented Progress & Features:

I have successfully designed, implemented, and verified the brand-new, premium **Saved Recipes / Cookbook** feature in PalengkeGo! Tapping the cookbook icon in the top right takes the user to a dedicated list of favorited recipes, complete with a delightful illustration for the empty state.

---

## 🛠️ Changes Implemented

### 1. Cookbook SVG Icon Asset
#### [NEW] [cookbook.svg](file:///c:/Users/fragi/Videos/PalengkeGoAPP/assets/icons/cookbook.svg)
* Added a custom vector asset representing a cookbook (a book containing cooking symbols). Uses `currentColor` to dynamically support branding colors and theme shifts.

### 2. State Management via Modern Notifier
#### [NEW] [saved_recipes_provider.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/features/recipes/application/saved_recipes_provider.dart)
* Implemented `SavedRecipesNotifier` extending Riverpod's modern `Notifier` to avoid deprecated `ChangeNotifierProvider` issues.
* Manages a reactive list of saved recipes, with utility methods `isSaved(recipe)` and `toggleSave(recipe)`.

### 3. Recipes List Screen Integration
#### [MODIFY] [recipes_screen.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/features/recipes/presentation/pages/recipes_screen.dart)
* Added the Cookbook SVG icon button in the header that routes to the Cookbook screen.
* Overlaid a translucent circular Heart button on the Featured Recipe card.
* Added an interactive Heart button on each recipe card in the "More Recipes" list.
* Connected both buttons directly to `savedRecipesProvider` for instant updates and local state updates.

### 4. Route Registration
#### [MODIFY] [app_routes.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/core/navigation/app_routes.dart) and [app_router.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/core/navigation/app_router.dart)
* Added route name constant `/cookbook` and registered `CookbookScreen` using a premium slide route transition.

### 5. Details Screen Integration
#### [MODIFY] [recipe_details_screen.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/features/recipes/presentation/pages/recipe_details_screen.dart)
* Converted the page to a `ConsumerStatefulWidget` and `ConsumerState`.
* Watched the global `savedRecipesProvider` to show the correct favorite icon status dynamically.
* Tapping the favorite button in the top-right updates the global saved list state instantly.

### 6. Created Cookbook Screen
#### [NEW] [cookbook_screen.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/features/recipes/presentation/pages/cookbook_screen.dart)
* Created a dedicated screen matching **Probe A** design:
  * **Header**: Slim, custom header with a back button and title "My Cookbook".
  * **Interactive List**: Renders saved recipes with heart actions that trigger slide removing and show undo Snackbar toasts.
  * **Delightful Empty State**: Shows a green circle-bound book illustration and a cozy prompt encouraging users to explore and save recipes, with a direct green button back to the main list.

---

## 🧪 Verification & Interactive Steps

1. **Verify Asset and Route**:
   * Open the Recipes tab. Look at the top right of the title bar to see the new **Cookbook** icon.
   * Tap it; you should see the **My Cookbook** screen slide in.
2. **Explore Empty State**:
   * In the Cookbook screen, verify the custom illustative empty state.
   * Tap the **"Explore Recipes"** button to return to the Recipes screen.
3. **Toggle Hearts and Syncing**:
   * On the Featured Recipe (Sinigang na Hipon), tap the Heart icon in the top right. A Snackbar will confirm it's saved.
   * Open "Chicken Adobo" and tap the Heart button on its card.
   * Tap the top-right Cookbook icon. You will see both saved recipes listed!
   * Tap the Heart button on Chicken Adobo's list tile inside the Cookbook screen. Observe that it removes it and shows an **"Undo"** snackbar option.
   * Tap Sinigang na Hipon to open details. Notice the Heart button in the details screen is filled red. Tap it to unfavorite, then press back to see it removed from the lists.

---

### 📅 Session: Vendor Profile & Stall Settings Modularization
* **Date:** May 29, 2026
* **Session ID:** `8fea0672-b57c-4c3c-935a-2866df9226d9`

#### 🛠️ Implemented Progress & Features:

Successfully executed the cleanup and modularization of the vendor feature by splitting three oversized screen monoliths, extracting inline data models to the shared domain layer, and cleaning up Flutter deprecation warnings.

## Summary of Changes

### 1. Domain Model Consolidation
Extracted private inline data classes to shared domain models under `lib/features/vendors/domain/`:
- **`vendor_order_item.dart`**: Promoted `_VendorOrder` from `vendor_orders_screen.dart`.
- **`vendor_stall_product.dart`**: Promoted `_VendorProduct` from `vendor_products_screen.dart`.
- **`day_schedule.dart`**: Promoted `DaySchedule` from `vendor_stall_settings_screen.dart`.

### 2. Stall Settings Screen Split (869 → ~160 lines)
Decoupled the massive settings layout into focused, self-contained widgets under `lib/features/vendors/presentation/widgets/`:
- **`stall_photo_editor.dart`**: Overlap cover card + profile avatar picker sheets.
- **`stall_info_form.dart`**: Fields for name, description, location, and category.
- **`operating_hours_editor.dart`**: Operating schedule grid with native time pickers.
- **`stall_settings_save_button.dart`**: Reusable validation & submit trigger button.
- **`vendor_stall_settings_screen.dart`**: Composes the children, orchestrating local controllers and singleton updates.

### 3. Onboarding Screen Split (818 → ~260 lines)
Extracted multi-step onboarding sections under `lib/features/vendors/presentation/widgets/`:
- **`onboarding_business_info_step.dart`**: Business credentials uploading and validation mapping.
- **`onboarding_registered_name_step.dart`**: Legal identification naming input fields.
- **`onboarding_id_card_step.dart`**: Philippine government credentials selection step list.
<<<<<<< HEAD
- **`onboarding_phone_step.dart`**: Phone verification & simulation request field.
=======
>>>>>>> origin/main
- **`onboarding_bottom_buttons.dart`**: Forward, backward, and verification action bar.
- **`vendor_onboarding_screen.dart`**: Coordinates navigation steps, animation curves, and final transition to dashboard.

### 4. Dashboard Screen Split (632 → ~340 lines)
Split the dashboard shell and home screen view components under `lib/features/vendors/presentation/widgets/`:
- **`dashboard_sales_card.dart`**: High-fidelity overview card outlining daily PHP revenue and operational stat grids.
- **`dashboard_stall_card.dart`**: Cover image, profile logo, address, and live open status toggle.
- **`dashboard_recent_order_card.dart`**: Order billing item lines with preparations launch triggers.
- **`vendor_dashboard_screen.dart`**: Simple navigator handling bottom navigation tabs and general status change hooks.

### 5. Orders & Products Screens Refactoring
Refactored the tabs to consume the newly shared model files:
- **`vendor_orders_screen.dart`**: Swapped local `_VendorOrder` list with `VendorOrderItem`.
- **`vendor_products_screen.dart`**: Swapped local `_VendorProduct` list with `VendorStallProduct`.

### 6. Flutter Color API Deprecations Cleanup
- Resolved deprecation alerts by replacing `.withOpacity(x)` with `.withValues(alpha: x)` across all modified files and additional pages:
  - `vendor_add_product_screen.dart`
  - `vendor_notifications_screen.dart`
- Resolved unnecessary `const` warnings inside list declarations.

---

## Verification Results

### Automated Checks
- **Static Analysis (`flutter analyze`):** Complete clean pass with **0 issues or warnings** inside the vendor feature package path.
- **Unit Tests (`flutter test`):** **25/25 tests passed successfully** without any regressions.

---

### 📅 Session: Codebase Audit, Card Layout Overflow Fixes, and Focus Crashes
* **Date:** May 30, 2026
* **Session ID:** `ec2dcd81-3875-445a-a87a-fae43a8a41a4`

#### 🛠️ Implemented Progress & Features:

Here is the documentation for the bugs we successfully squashed during our debugging session:

## 1. Market Filter Category Mismatch
> [!WARNING]
> **Bug:** The market filter was looking for exact category string matches (e.g., `"Meat"`). However, the actual dropdown choices and data generated for vendors used slightly different strings (e.g., `"Meat & Poultry"`). This caused valid products to be completely omitted when filtering.

**Fix Applied:**
- Updated the data model bridging so that products inherit their vendor's exact category if none is specified.
- Replaced the strict equality (`==`) checks with `.contains()` checks in both the repository data fetching (`mock_market_repository.dart`) and the vendor profile sorting (`vendor_profile_screen.dart`).

## 2. Silent Crash on Saving New Products
> [!CAUTION]
> **Bug:** After adding a new product, the UI would freeze and the user received no confirmation. The terminal silently threw a `deactivated widget's ancestor` error alongside a `Bad state` error.

**Fix Applied:**
- **Provider Family Issue:** Removed an invalid `ref.invalidate(filteredVendorsProvider)` call from `vendor_provider.dart`. `filteredVendorsProvider` is a family provider and cannot be invalidated generically. Doing so caused an asynchronous throw right after the product saved.
- **ScaffoldMessenger Safety:** The success snackbar was trying to use a local `ScaffoldMessenger` context precisely as the screen was popping off the navigation stack. To guarantee stability and user visibility, this was replaced with a `showDialog` (AlertDialog).

## 3. Product Cards Displaying Incorrect Data
> [!NOTE]
> **Bug:** In the customer-facing vendor stall (`VendorProfileScreen`), the product cards were displaying text like "Fresh cuts" and "Boneless" instead of the expected categories.

**Fix Applied:**
- Modified `VendorProfileProductCard` in `vendor_profile_components.dart` to bind correctly to `product.category` rather than `product.description`.

## 4. Unused Import Warning
> [!TIP]
> **Bug:** Removing the invalid `ref.invalidate` for the filter caused a linter warning in `vendor_provider.dart`.

**Fix Applied:**
- Cleaned up the unused `search_provider.dart` import at the top of the file to maintain pristine code hygiene.

#### 🐛 Bug Documentation & Fix Logs (Artifacts):
##### Artifact File: `bugs_documentation.md`

## Bug 1: Unclickable "Add to cart" button / UI Overflows on Product Cards
**Root Cause**: The `VendorProfileProductCard` used a fixed height for the image (`126.75` or `110`) and an aspect ratio in the `GridView` that didn't provide enough vertical space for the text and buttons underneath the image. This caused a bottom overflow, pushing the `+` button outside the tap target area, rendering it unclickable.
**Fix Implemented**: Switched the image container inside the card to use `Expanded` instead of a fixed `SizedBox(height: ...)`. This ensures the image dynamically takes up whatever vertical space is left after the text and buttons are rendered, preventing overflow regardless of the screen size. The grid's `childAspectRatio` was adjusted to provide a balanced card height.

## Bug 2: "Looking up a deactivated widget's ancestor is unsafe" in Add Product Screen
**Root Cause**: The `VendorAddProductScreen` experienced layout changes (such as replacing the image placeholder with a loaded image via "Change Image" or swapping UI elements on category selection) while a `TextField` was still focused. If the user had the keyboard open or focus on the `TextField`, and then tapped "Change Image", the widget tree would rebuild and adjust the layout. The text selection overlays would asynchronously attempt to clean up or reposition themselves by calling `Scaffold.of(context)`, resulting in a crash because the previous state was unstable or unmounted.
**Fix Implemented**: Added `FocusScope.of(context).unfocus()` to the "Change Image" button and Category Picker to safely drop keyboard focus before any `setState` triggers a layout shift. Additionally, unified the two price controllers into a single `_priceController` to prevent unnecessary widget destruction during category changes.

## Bug 3: Hardcoded "kg" and "pc" units across the app
**Root Cause**: The application relied on the mock data's `pricePerKg` and `weight` properties, which were hardcoded to `kg` for all items, including fruits and vegetables. The UI components (like the Add to Cart bottom sheet and Product Cards) also hardcoded the string `'kg'`.
**Fix Implemented**:
- Centralized a helper function `isPieceUnit(product)` that checks the category, product name, or description to accurately determine if an item is sold by pieces or by weight.
- Replaced hardcoded `/kg` text in all Product Cards (Customer and Vendor views) with a dynamic check that outputs `/KG/s` or `/PC/s`.
- Replaced the quantity pill label in the bottom sheet to explicitly show `KG/s` and `PC/s`.

## Bug 4: RenderFlex Layout Crash (Blank White Space) in Vendor Profile
**Root Cause**: The inner `Column` of the details section in `VendorProfileProductCard` contained a `Spacer()` widget. Because this Column was a child of a `Padding` which had no bounded height constraints in the vertical axis, it was laid out with an unbounded height constraint (`0.0 <= h <= Infinity`). Flex children like `Spacer` or `Expanded` cannot be laid out in an unbounded direction, causing a runtime `RenderFlex` exception that completely crashed the grid view and resulted in a blank screen.
**Fix Implemented**: Replaced the `Spacer()` widget with a fixed `SizedBox(height: 8)` and reduced details padding to make the layout extremely robust, layout-safe, and compact. The outer `Column`'s `Expanded` image container now dynamically expands to fill the remaining space without layout exceptions.

## Bug 5: Hardcoded Quantity Units in Checkout and Order Details
**Root Cause**: In the Checkout Order Item (`checkout_order_item.dart`) and Order Details (`order_details_items_list.dart`), the quantity unit was hardcoded as `kg` (e.g. `${item.quantity}kg` and `₱${item.pricePerKg}/kg`). This incorrectly showed piece-based items (like sweet mangoes or bananas) as kilograms.
**Fix Implemented**:
- Updated `checkout_order_item.dart` to dynamically determine if the item is a piece unit or weight unit and format the label accordingly (e.g. `PC/s` or `KG/s`).
- Updated `OrderLineItem`'s `quantityLabel` getter to output uppercase units (`PC/s` and `KG/s`).
- Corrected the price label display in `order_details_items_list.dart` to use the dynamic `pricePerKg` property directly without hardcoding `/kg`.

## Bug 6: Hardcoded Stats Card on Vendor Dashboard
**Root Cause**: The stats card (`DashboardSalesCard`) displaying Today's Sales, Pending Orders count, and Completed Orders count on the vendor dashboard was completely static and hardcoded (e.g., displaying `PHP 4,250.00`, `12 Orders`, and `45 Orders`). Furthermore, the dashboard header greeting was hardcoded to greet `"Mang Juan"`.
**Fix Implemented**:
- Refactored `DashboardSalesCard` to be a `ConsumerWidget` that watches the live `vendorOrdersProvider`.
- Calculated Today's Sales, Pending Orders, and Completed Orders counts dynamically from the live list of vendor orders.
- Updated the greeting header to dynamically resolve the logged-in vendor's display name or stall name from `authProvider` and `vendorStallProvider`.

## Bug 7: "BOTTOM OVERFLOWED BY 55 PIXELS" in Vendor Add Product Category Picker
**Root Cause**: The Category Picker modal bottom sheet used a simple `Column` wrapped in a `SafeArea` with `mainAxisSize: MainAxisSize.min`. Because the list of categories was long, the column exceeded the available height constraint of the bottom sheet, causing a render overflow.
**Fix Implemented**: Wrapped the inner `Column` of the category picker with a `SingleChildScrollView` to make the list scrollable, and added `isScrollControlled: true` to `showModalBottomSheet` so it can expand beyond the default half-screen height limit safely without overflowing.

## Bug 8: Multiple duplicate items added silently (No feedback on "Save Product")
**Root Cause**: Clicking the "Save Product" button triggered a layout shift (replacing the button text with a `CircularProgressIndicator`) while the user's keyboard was still focused on a text input (e.g. price). When `setState({ _isSaving = true })` executed, the keyboard overlays attempted to reposition or close during the widget rebuild, causing a framework-level `FlutterError` ("Looking up a deactivated widget's ancestor is unsafe"). This exception halted the rest of the `_saveProduct` asynchronous execution. The product was added to the mock database, but the code to show the success `SnackBar` and `Navigator.pop(context)` was never reached. The user, seeing no visual feedback, repeatedly clicked the button, unintentionally adding duplicate items.
**Fix Implemented**: Added `FocusScope.of(context).unfocus();` at the very beginning of the `_saveProduct` function. This explicitly dismisses the keyboard and safely settles the focus state *before* any state updates or asynchronous operations run, completely preventing the layout crash. The execution now successfully completes, showing the feedback `SnackBar` and closing the screen.

## Bug 9: Track Order Screen uncompleted status step (Delivering vs Ready)
**Root Cause**: The `TrackOrderScreen` was checking `currentOrder.status == OrderStatus.delivering` to mark the "Out for Delivery" step as active. However, the `OrderStatus` enum uses `ready` (not `delivering`), causing the progress timeline to fail to update for that specific state.
**Fix Implemented**: Corrected the status check in `TrackOrderScreen` to use `OrderStatus.ready` instead of `OrderStatus.delivering`.

## Bug 10: Vendor Dashboard Recent Orders Action Button Desync
**Root Cause**: The `DashboardRecentOrderCard` component had its button text hardcoded to `"Start Preparing"`. When the vendor confirmed an order on the orders page, the dashboard card still displayed "Start Preparing" instead of "View Order", leading to a desync between the actual order status and the dashboard's call to action.
**Fix Implemented**: Added a `primaryActionText` property to `DashboardRecentOrderCard`. Updated `vendor_dashboard_screen.dart` to dynamically pass either `"Start Preparing"` or `"View Order"` based on whether the `order.status` is `OrderStatus.pending`.

## Bug 11: Add Product Form Silent Failure to Close
**Root Cause**: Despite the previous fix for the layout shift, the `_saveProduct` function was vulnerable to missing exceptions or unmounted context issues when calling `ScaffoldMessenger.of(context)` and `Navigator.pop(context)` after the asynchronous `addProduct` call.
**Fix Implemented**: Wrapped the `addProduct` call in a comprehensive `try-catch` block. Pre-captured `ScaffoldMessenger.of(context)` and `Navigator.of(context)` before the `await` gap to safely show a success snackbar and pop the screen.

## Bug 12: Market Category Filter Ignoring Vendor Products
**Root Cause**: The `filteredVendorsProvider` relied on `marketRepository.getVendorsByCategory()`, which only checked the main vendor stall category (e.g., "Fruits") but did not check if the vendor had any products matching the selected category (e.g., "Meat"). Additionally, the Vendor Profile screen did not receive the selected category to filter its displayed products.
**Fix Implemented**: 
- Updated `MockMarketRepository.getVendorsByCategory` to scan all products associated with the vendor and include the vendor if any product matches the category.
- Passed `_selectedCategory` from the `MarketScreen` through `StallCard` to the `VendorProfileScreen`.
- Updated `VendorProfileScreen` to filter its grid of displayed products by the injected `filterCategory`, ensuring only the requested items (e.g., Meat items) are visible when navigating from a filtered market search.

##### Artifact File: `bug_documentation.md`

Here is the documentation for the bugs we successfully squashed during our debugging session:

## 1. Market Filter Category Mismatch
> [!WARNING]
> **Bug:** The market filter was looking for exact category string matches (e.g., `"Meat"`). However, the actual dropdown choices and data generated for vendors used slightly different strings (e.g., `"Meat & Poultry"`). This caused valid products to be completely omitted when filtering.

**Fix Applied:**
- Updated the data model bridging so that products inherit their vendor's exact category if none is specified.
- Replaced the strict equality (`==`) checks with `.contains()` checks in both the repository data fetching (`mock_market_repository.dart`) and the vendor profile sorting (`vendor_profile_screen.dart`).

## 2. Silent Crash on Saving New Products
> [!CAUTION]
> **Bug:** After adding a new product, the UI would freeze and the user received no confirmation. The terminal silently threw a `deactivated widget's ancestor` error alongside a `Bad state` error.

**Fix Applied:**
- **Provider Family Issue:** Removed an invalid `ref.invalidate(filteredVendorsProvider)` call from `vendor_provider.dart`. `filteredVendorsProvider` is a family provider and cannot be invalidated generically. Doing so caused an asynchronous throw right after the product saved.
- **ScaffoldMessenger Safety:** The success snackbar was trying to use a local `ScaffoldMessenger` context precisely as the screen was popping off the navigation stack. To guarantee stability and user visibility, this was replaced with a `showDialog` (AlertDialog).

## 3. Product Cards Displaying Incorrect Data
> [!NOTE]
> **Bug:** In the customer-facing vendor stall (`VendorProfileScreen`), the product cards were displaying text like "Fresh cuts" and "Boneless" instead of the expected categories.

**Fix Applied:**
- Modified `VendorProfileProductCard` in `vendor_profile_components.dart` to bind correctly to `product.category` rather than `product.description`.

## 4. Unused Import Warning
> [!TIP]
> **Bug:** Removing the invalid `ref.invalidate` for the filter caused a linter warning in `vendor_provider.dart`.

**Fix Applied:**
- Cleaned up the unused `search_provider.dart` import at the top of the file to maintain pristine code hygiene.

---

### 📅 Session: Cart & Order Integrity Planning
* **Date:** June 14, 2026
* **Session ID:** `3c49d767-71ae-443f-9f5d-5b9652e20586`

*No standalone walkthrough documented in this session.*

#### 🐛 Bug Documentation & Fix Logs (Artifacts):
##### Artifact File: `bug_documentation.md`

Here is the documentation for the bugs we successfully squashed during our debugging session:

## 1. Market Filter Category Mismatch
> [!WARNING]
> **Bug:** The market filter was looking for exact category string matches (e.g., `"Meat"`). However, the actual dropdown choices and data generated for vendors used slightly different strings (e.g., `"Meat & Poultry"`). This caused valid products to be completely omitted when filtering.

**Fix Applied:**
- Updated the data model bridging so that products inherit their vendor's exact category if none is specified.
- Replaced the strict equality (`==`) checks with `.contains()` checks in both the repository data fetching (`mock_market_repository.dart`) and the vendor profile sorting (`vendor_profile_screen.dart`).

## 2. Silent Crash on Saving New Products
> [!CAUTION]
> **Bug:** After adding a new product, the UI would freeze and the user received no confirmation. The terminal silently threw a `deactivated widget's ancestor` error alongside a `Bad state` error.

**Fix Applied:**
- **Provider Family Issue:** Removed an invalid `ref.invalidate(filteredVendorsProvider)` call from `vendor_provider.dart`. `filteredVendorsProvider` is a family provider and cannot be invalidated generically. Doing so caused an asynchronous throw right after the product saved.
- **ScaffoldMessenger Safety:** The success snackbar was trying to use a local `ScaffoldMessenger` context precisely as the screen was popping off the navigation stack. To guarantee stability and user visibility, this was replaced with a `showDialog` (AlertDialog).

## 3. Product Cards Displaying Incorrect Data
> [!NOTE]
> **Bug:** In the customer-facing vendor stall (`VendorProfileScreen`), the product cards were displaying text like "Fresh cuts" and "Boneless" instead of the expected categories.

**Fix Applied:**
- Modified `VendorProfileProductCard` in `vendor_profile_components.dart` to bind correctly to `product.category` rather than `product.description`.

## 4. Unused Import Warning
> [!TIP]
> **Bug:** Removing the invalid `ref.invalidate` for the filter caused a linter warning in `vendor_provider.dart`.

**Fix Applied:**
- Cleaned up the unused `search_provider.dart` import at the top of the file to maintain pristine code hygiene.

## 5. Deactivated Widget's Ancestor Errors on Async Actions
> [!CAUTION]
> **Bug:** "Looking up a deactivated widget's ancestor is unsafe" exceptions were thrown repeatedly when deleting a product or using context-dependent widgets after async operations (like awaiting `showDialog` or `deleteProduct`). This is a known issue on Flutter Web when interacting with contexts across `await` gaps or list items undergoing lifecycle changes, as `ScaffoldMessenger.of(context)` or `Navigator.of(context)` try to traverse deactivated elements.

**Fix Applied:**
- **Post Frame Callbacks:** Refactored action handlers (e.g., `_deleteProduct`, `_saveProduct`) to trigger context-dependent dialogs via `WidgetsBinding.instance.addPostFrameCallback`. This guarantees the element tree is fully stable and layout complete before proceeding.
- **Synchronous Pre-capture:** Pre-captured variables like `ref.read` and `Navigator.of(context)` synchronously *before* `await` boundaries.
- **Global `ScaffoldMessengerKey` (`AppServices`):** Abstracted `ScaffoldMessenger` out of local contexts entirely by setting up `AppServices.scaffoldMessengerKey` on `MaterialApp`. All snackbars (`AppServices.showSnackBar`) now use this global key directly (also wrapped in `addPostFrameCallback`), completely bypassing context traversals (`findAncestorStateOfType`) that fail on deactivated widget trees.

---

### 📅 Session: Saved & Blocked Stalls UI Implementation
* **Date:** June 14, 2026
* **Session ID:** `e19e5a75-68d0-4fba-b9b2-b890b8612343`

#### 🛠️ Implemented Progress & Features:

The "Saved Stalls" screen has been implemented following the `/impeccable` guidelines to seamlessly manage your favorited and blocked stalls. Here's a breakdown of the new feature:

## What Was Added

1. **Saved Stalls Screen (`saved_stalls_screen.dart`)**:
   - Built a clean, minimalist UI consistent with the app's light theme.
   - Designed an elegant sliding pill toggle (`AnimatedPositioned`) to switch between **Favorites** and **Blocked** tabs seamlessly.
   - Displayed standard stall cards dynamically fetched from the app's repository.
   - Created beautiful empty states with clear iconography to avoid blank screens.

2. **State Management**:
   - Added `blockedVendorsListProvider` to convert blocked vendor IDs back into rich `MarketVendor` data, perfectly mirroring the favorites provider logic.

3. **Profile Integration**:
   - Inserted the new "Saved Stalls" menu item on your `ProfileScreen` directly below Edit Profile.

## Verification

- **Real Data Binding**: The lists react immediately to Riverpod state updates. Unblocking or unfavoriting a vendor immediately removes them from the screen.
- **Animations**: The segmented pill smoothly animates back and forth over 300ms using a fast-out-slow-in curve, creating an impeccable micro-interaction.
- **No Hardcoding**: Everything fetches true `MarketVendor` instances using existing app data sources.

> [!TIP]
> Since we added a completely new file (`saved_stalls_screen.dart`) and modified state providers, you should perform a **Hot Restart** (`R` in the terminal or full page refresh in your web browser) if hot reload fails to stitch the new file into the app automatically!

---

### 📅 Session: Block/Report Flow & Deactivated Context Bug Fixes
* **Date:** June 18, 2026
* **Session ID:** `902c41f0-79ed-4ece-994e-de3bf3d210ef`

#### 🛠️ Implemented Progress & Features:

I have fixed the "deactivated widget's ancestor is unsafe" exceptions when blocking and reporting vendors on Flutter Web, and ensured that blocked vendors are correctly filtered out from the Favorites tab.

## Changes Made

### 1. Vendor Blocking & Popping Navigation (`block_vendor_dialog.dart`)
- **Before**: Pushed the block action and used `navigator.popUntil` with target name `/main` or `isFirst`. This popped the `SavedStallsScreen` along with the profile page and dialog when blocking from favorites, which did not return the user to the saved stalls screen they came from. It also used `messenger.showSnackBar` using the dialog's local `BuildContext` right after popping, leading to the deactivated context lookup crash.
- **After**: Changed the navigation to pop exactly twice (`navigator.pop()` for the dialog, and `navigator.pop()` for the `VendorProfileScreen`). This correctly returns the user to the exact screen they pushed the profile from. Also, the snackbar is shown using the global `AppServices.showSnackBar`, which is completely safe against widget deactivation.

### 2. Vendor Reporting (`flag_vendor_bottom_sheet.dart`)
- **Before**: Called `ScaffoldMessenger.of(context).showSnackBar` on the bottom sheet's context immediately after calling `Navigator.pop(context, true)`. Since the bottom sheet was popped, its context was deactivated, throwing the "deactivated widget's ancestor is unsafe" exception.
- **After**: Switched to `AppServices.showSnackBar` so that the success snackbar is triggered globally without using the deactivated context.

### 3. Favorites List Filter (`favorites_provider.dart`)
- **Before**: `favoriteVendorsProvider` only checked if a vendor was in favorites, but ignored whether they were blocked.
- **After**: Modified `favoriteVendorsProvider` to watch both `favoritesProvider` and `blockedVendorsProvider`, filtering out any blocked vendors. This makes the vendor card disappear from the Favorites tab immediately upon being blocked.

## Verification & Testing
- Ran all unit tests using `flutter test`. All **97 tests passed successfully**.

---

### 📅 Session: NotebookLM Integration
* **Date:** June 23, 2026
* **Session ID:** `0c380015-f4f0-4c62-a6d6-e78aecebce3b`

*No standalone walkthrough documented in this session.*

---

### 📅 Session: Product Weight Picker & Location Selection Implementation
* **Date:** June 24, 2026
* **Session ID:** `49db36f1-b758-47c9-8fb4-0dad995fd76c`

#### 🛠️ Implemented Progress & Features:

I have completed the implementation for the multiple saved locations feature based on your desired behavior.

## Changes Made

1. **State Management**: Updated `CustomerPreferencesState` to support `savedAddresses` (a list of `DeliveryAddress`), initially seeded with a few mock locations (e.g., Home, School) for demonstration.
2. **Registration Enforcement**: Modified the `RegistrationScreen` so that users are strictly required to set their delivery location using the map mock before they can successfully create an account. If they attempt to register without doing so, they are presented with an error SnackBar.
3. **Location Selection Bottom Sheet**: Created a new `LocationSelectionSheet` widget mirroring the FoodPanda style.
   - Allows users to switch between saved locations.
   - Includes a "+ Select a different location" button to add a new one.
4. **Home Screen Header**: Updated `HomeHeader` to feature the tappable location indicator. It shows the current active location (e.g., "Home • Magsaysay Ave") and when clicked, opens the `LocationSelectionSheet`. This behaves identically for both guests and authenticated users, keeping browsing uninterrupted.
5. **Address Form Upgrade**: Updated `SetDeliveryAddressScreen` to add a new `label` input field ("Home", "Work", etc.) so users can name their new custom saved addresses.
6. **Profile Settings**: Added a "My Addresses" button to the `ProfileScreen` menu for authenticated users, which also summons the location selection bottom sheet for easy management.

## Validation Results

- A user can now seamlessly tap the delivery header while browsing, switch to a saved location like "School", or add a brand new one.
- The active address is now centrally driven by the `preferencesProvider`, applying site-wide immediately upon confirmation.
- The registration flow actively enforces location gathering upfront.

#### 🐛 Bug Documentation & Fix Logs (Artifacts):
##### Artifact File: `bug_documentation.md`

## Product Weight Picker & Stock Unit Bug

**Description**
When editing a product to put it on sale (or changing any other property), the unit in the weight picker would switch from `kg` (or whatever its original unit was) to `pieces` (`pc`) for certain categories like Fruits and Vegetables. 
Additionally, the vendor product stock list always displayed the stock unit as `kg` regardless of whether the product was actually sold by pieces or kg.

**Root Cause**
1. **Edit Screen Overwrite:** `vendor_add_product_screen.dart` used a hardcoded getter `_isPieceUnit` that automatically set the unit to pieces if the category was `Fruits`, `Vegetables`, `Maritatas`, or `Sari-Sari`. This overwrote the existing `pricePerKg` format (like `PHP 150/kg` -> `PHP 150/pc`) when saving the product.
2. **Stock Display Issue:** In `vendor_products_screen.dart` and `vendor_profile_components.dart`, the unit was derived using a name-based heuristic `UnitHelper.isPieceUnit` (which checks if the product name contains "mango", "banana", etc.), completely ignoring the actual formatted `pricePerKg` property of the product.
3. **UnitHelper Bug:** The `UnitHelper.getUnitString` method was hardcoded to `return 'kg';` in all cases, causing all stock readouts to end with `kg`.

**Fix Applied**
- Fixed `UnitHelper.getUnitString` to return `'pc'` if `isPiece` is true, otherwise `'kg'`.
- Added `UnitHelper.isPieceProduct(product)` to reliably check for `/kg` or `/pc` directly from the product's `pricePerKg` string, rather than guessing based on the name.
- Updated `vendor_products_screen.dart` and `vendor_profile_components.dart` to use the accurate `UnitHelper.isPieceProduct` for displaying units.
- Updated `vendor_add_product_screen.dart` to preserve the product's original unit when in edit mode, preventing it from incorrectly resetting fruits and vegetables to pieces.

## Vendor Stall Image Persistence Bug

**Description**
When a vendor uploaded a new profile picture (avatar) or stall banner, the new images appeared in the vendor dashboard. However, navigating away to the customer UI and returning to the vendor UI caused the images to reset to the default placeholders. Additionally, the customer UI (where customers browse the stall) never reflected the new images, continuing to display Unsplash placeholders.

**Root Cause**
1. **Vendor UI Persistence (`VendorStallNotifier`)**: The `VendorStallNotifier` was strictly synchronous. Upon initialization (`build()`), it created a fallback `VendorStall` object from hardcoded defaults instead of fetching the saved state from the `VendorRepository`. When the vendor navigated away, the provider was disposed, and returning caused it to rebuild from the defaults, effectively "forgetting" the uploaded images for that session.
2. **Customer UI Disconnect (`MockVendorRepository`)**: When the vendor saved their stall settings, `MockVendorRepository.updateVendorStall` correctly updated its internal `_mockStall` variable. However, the Customer UI populated stall data by reading `MockDataService.featuredVendors`. The `updateVendorStall` method did not sync changes back to the `featuredVendors` list, leaving the customer-facing data stale.

**Fix Applied**
- **State Hydration**: Updated `vendor_stall_provider.dart` to fire an asynchronous `Future.microtask` during its synchronous `build()` phase. It immediately returns the fallback state (to prevent UI crashes) but seamlessly fetches the actual saved `VendorStall` from the repository in the background and updates its state, preserving uploaded images.
- **Bi-Directional Mock Sync**: Updated `mock_vendor_repository.dart` so that when `updateVendorStall` is called, it actively searches for the corresponding vendor in `MockDataService.featuredVendors` and updates the `imageUrl` and `avatarUrl` fields there as well. This ensures changes are immediately visible to the Customer UI.

---

### 📅 Session: Antigravity Skills evaluation
* **Date:** June 30, 2026
* **Session ID:** `a71139fa-f801-4b7e-9f9c-d7e22e585e40`

*No standalone walkthrough documented in this session.*

---

### 📅 Session: Adaptive Image Loading & Open/Close Syncing
* **Date:** July 05, 2026
* **Session ID:** `93e14144-e372-4443-aeb9-96fbe8365b75`

#### 🛠️ Implemented Progress & Features:

I've completed the implementation plan to address the image loading errors, stall open/close syncing, and the map obstruction issue.

## 1. Adaptive Image Rendering
When you pick an image from your device's gallery, it comes through as a local file rather than a web URL. The `NetworkImage` widget natively only supports `http`/`https` protocols and would fail when given a local file.

**Changes Made:**
- Replaced all explicit `NetworkImage` usages with PalengkeGo's `AdaptiveImage` in:
  - `VendorProfileProductCard`
  - `VendorProductsScreen`
  - `AddToCartBottomSheet`
  - `DiscountedItemCard`
- The app will now seamlessly render products regardless of whether their image comes from the web or your local device gallery.

## 2. Vendor Stall Status Syncing
The Customer Home Screen (`StallCard`) was incorrectly hardcoding the vendor's status to always say "OPEN".

**Changes Made:**
- Added the `isOpen` boolean field to the `MarketVendor` data model.
- Updated the `MarketVendor` model mapping (`fromMap`/`toMap`) to safely fetch the live `isOpen` status from the mock data.
- Rewrote the `_statusFor()` logic in `stall_card.dart` to read `vendor.isOpen`.
- Now, when a vendor toggles their stall status to "Closed" in the Vendor Dashboard, the customer's feed will instantly reflect the "CLOSED" badge.

## 3. Impeccable Delivery Map UI
The frosted glass card on the `SetDeliveryAddressScreen` was statically pinned to the bottom of the screen, which severely obstructed the user's view of the map and made dropping the pin difficult.

**Changes Made:**
- Converted the static `Positioned` panel into a native `DraggableScrollableSheet`.
- Added a sleek "pill" drag indicator to the top of the card.
- The card now spawns partially collapsed, giving a wide, clear view of the map. 
- You can seamlessly swipe the card up to fully expand it and enter your delivery details, then swipe it back down to adjust the map.

## Next Steps
You can now run `flutter run` and test out these specific scenarios. The device images should load instantly, the stall toggle should sync to the customer view, and the map card should be highly interactable!

---

### 📅 Session: Recipes & Notifications Refactoring, Quantity Picker, and KYC Processing
* **Date:** July 07, 2026
* **Session ID:** `1ee0c52e-64b1-4ba2-ae43-89493862aca0`

#### 🛠️ Implemented Progress & Features:

We have successfully completed all adjustments and verified them with a clean compilation. Here is the summary of the work done:

## Changes

### 1. Refactored Recipe Suggestions Trigger & Widget
- **Removed Checkout-time Notification Trigger**: Deleted the immediate recipe notification trigger from [checkout_screen.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/features/checkout/presentation/pages/checkout_screen.dart).
- **Completed-time Notification Trigger**: Programmed the notification to trigger ONLY when an order's status transitions to `OrderStatus.completed` (e.g. marked complete in [notification_service.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/core/services/notification_service.dart)). The suggestion is dynamically computed from the purchased ingredients retrieved via `SharedOrderStore`.
- **Removed Track Order Suggestions**: Deleted the horizontal suggestion cards and removed the `_RecipeSuggestionsCard` widget definition from [order_confirmation_screen.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/features/checkout/presentation/pages/order_confirmation_screen.dart).

### 2. Auto-Clearing Recipe Tab Indicator Badge
- **Clear Badge on Active Tab**: Added a post-frame callback in [main_screen.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/features/main/presentation/pages/main_screen.dart) so that whenever the Recipes tab (index 3) is selected, all recipe notifications are immediately marked as read.
- **markAllOfTypeRead Method**: Added a helper to `NotificationService` in [notification_service.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/core/services/notification_service.dart) to cleanly dismiss unread flags for specific notification types.

### 3. Double Type and Mapping Cleanups
- **Parsed Stock Quantity as Double**: Adjusted `stockQuantity` parsing in [firebase_vendor_repository.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/features/vendors/data/firebase_vendor_repository.dart) to safely map as `double` from Firestore maps, matching the changed model properties.
- **CartItem Stock Type**: Changed the generated and factory constructor parameter types of `stockQuantity` in [cart_item.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/features/cart/domain/cart_item.dart) to `double` so cart operations succeed without casting errors.
- **Rebuilt Generated Files**: Successfully executed `build_runner` to regenerate types.
- **Cleaned Up Tests**: Updated product helper signatures in [vendor_profile_product_card_test.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/test/features/vendors/vendor_profile_product_card_test.dart) to take double values.

### 4. Backend & ERD Reconciliation Updates
- **MarketOrder Cancellation Reason**: Added the `cancellationReason` optional field to [MarketOrder](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/features/orders/domain/market_order.dart). Serialized and deserialized the field in the [FirebaseOrderRepository](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/features/orders/data/firebase_order_repository.dart) and [MockOrderRepository](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/features/orders/data/mock_order_repository.dart). Updated `updateOrderStatus` to automatically set the cancellation reason when an order is cancelled or rejected.
- **Notification Reference ID**: Added an optional `referenceId` to the `AppNotification` class in [notification_service.dart](file:///c:/Users/fragi/Videos/PalengkeGoAPP/lib/core/services/notification_service.dart) to enable deep-linking (e.g. tapping an order notification opens that specific `orderId`). Wired it up to pass the `orderId` dynamically on order status change events.
- **Rebuilt Generated Models**: Regenerated freezed classes (e.g. `market_order.freezed.dart`) using `flutter pub run build_runner build`.

---

## Verification Plan

### Automated Verification
- Ran `flutter analyze` and got a perfect `No issues found!` across the entire codebase.

---

### 📅 Session: Documentation Scraping & Project Progress Compilation
* **Date:** July 11, 2026
* **Session ID:** `592a8085-2bba-4aca-94fc-6dfe905bf5e8`

*No standalone walkthrough documented in this session.*

---

## 4. Setup & Running Locally

### Prerequisites
* Flutter SDK (v3.22.0+)
* Dart SDK (v3.4.0+)

### Step-by-Step Instructions
1. **Clone & Navigate:** Enter the repository root directory.
2. **Install Dependencies:** Fetch required packages by running:
   ```powershell
   flutter pub get
   ```
3. **Build Code Generators:** Generate freezed and JSON serialization source files by executing:
   ```powershell
   dart run build_runner build --delete-conflicting-outputs
   ```
4. **Run App:** Launch the app on a connected emulator, browser, or device:
   ```powershell
   flutter run -d chrome
   ```
5. **Run Tests:** Execute unit tests to verify system state changes:
   ```powershell
   flutter test
   ```

