# Audit Findings And Issues To Address

Date: 2026-06-04

## Summary

This audit reviewed the repository structure, docs, architecture direction, tests, Android config, and current refactor state. No code changes were made during the audit.

Overall rating: 7/10

The app is no longer just a static prototype. It has real local cart/order flow, tests, feature folders, repositories, and a clear refactor plan. It is a strong thesis/demo frontend, but it is not production-ready yet.

## Verification Results

- `flutter test`: passed, `25/25`.
- `flutter analyze`: failed the repo's documented zero-warning policy with `48 info` issues, all observed as deprecated `withOpacity(...)` usage.
- `flutter build apk --debug`: timed out after 5 minutes, so APK build readiness is unconfirmed.

## Category Ratings

### Architecture: 7/10

Good feature-based direction, but globals still exist behind providers.

Relevant files:

- `lib/core/services/cart_service.dart`
- `lib/features/cart/application/cart_provider.dart`

### State Management: 6/10

Riverpod is introduced, but cart/orders still use singleton `ChangeNotifier` services and manual listeners. This is acceptable as an intermediate refactor checkpoint, but it should be cleaned up before real backend or payment work.

### Test Coverage: 6.5/10

There is good unit coverage for cart, orders, and mock repositories. The widget test is still only a smoke test.

Relevant file:

- `test/widget_test.dart`

### Maintainability: 7/10

Many screens are still large and should continue being split into smaller display widgets and controllers.

Largest observed examples:

- `lib/features/checkout/presentation/pages/order_confirmation_screen.dart`: 691 lines
- `lib/features/vendors/presentation/pages/vendor_profile_screen.dart`: 565 lines
- `lib/features/orders/presentation/pages/order_details_screen.dart`: 565 lines

### Production Readiness: 5/10

Android still uses template-level package configuration and release signing is not ready.

Relevant files:

- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`

### Docs And Handoff Quality: 8/10

The docs are unusually useful and give a clear refactor direction. However, `docs/AI_HANDOFF.md` is partly stale. For example, it says multi-vendor checkout only confirms the first order, but the current code passes the full order list into the confirmation screen.

Relevant files:

- `docs/AI_HANDOFF.md`
- `lib/features/checkout/presentation/pages/checkout_screen.dart`
- `lib/features/checkout/presentation/pages/order_confirmation_screen.dart`

## Highest Priority Fixes

### 1. Clear Analyzer Policy Violations

Replace all deprecated `withOpacity(...)` calls with `withValues(alpha: ...)`.

Why it matters:

- The repo documents a zero-warning policy.
- `flutter analyze` currently reports 48 info-level issues.
- These are easy, mechanical cleanup items that unblock cleaner verification.

### 2. Finish Removing Global State Coupling

`CartService` still imports `main_screen.dart` only to update the bottom navigation badge. That couples core business state to presentation UI.

Relevant file:

- `lib/core/services/cart_service.dart`

Recommended direction:

- Move badge state into Riverpod/UI state.
- Stop calling UI update functions from the service layer.
- Eventually replace global singleton services with provider-owned services or Riverpod notifiers.

### 3. Complete Route Centralization

`AppRoutes` and `AppRouter` cover only part of the app. Some screens still use direct route pushes.

Relevant files:

- `lib/core/navigation/app_routes.dart`
- `lib/core/navigation/app_router.dart`
- `lib/features/orders/presentation/pages/order_history_screen.dart`
- `lib/features/vendors/presentation/pages/vendor_products_screen.dart`

Recommended direction:

- Add missing route names for order details and vendor flows.
- Replace remaining straightforward `MaterialPageRoute` / custom direct pushes with named routes.
- Keep custom transitions centralized.

### 4. Prepare Android Release Config

The Android project still uses template values like `com.example.palengkego`, and release signing still uses debug signing.

Relevant file:

- `android/app/build.gradle.kts`

Recommended direction:

- Set a real application ID/package namespace.
- Set production app label.
- Configure release signing.
- Confirm versioning policy.
- Replace launcher icons if needed.

### 5. Decide Persistence Strategy

Cart, orders, auth, and profile are still local/mock-only.

Recommended direction:

- Finalize repository contracts before backend work.
- Define offline behavior.
- Define order/payment lifecycle states.
- Define how vendor grouping works when orders are persisted.

### 6. Commit And Stage Carefully

The worktree has many modified and untracked files. Stage intentionally.

Also note:

- `.gitignore` currently ignores most docs files.
- `.gitignore` ignores `pubspec.lock`, which is usually not ideal for Flutter apps.

## What To Prepare For Next

- Backend integration will be easier if repository/provider boundaries are finished first.
- Payment work should wait until order models include payment state, fees, vendor grouping, and failure/cancel states.
- Before beta/demo packaging, run:
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug`
  - a real-device manual pass through customer and vendor flows

## Practical Next Work Order

1. Replace deprecated `withOpacity(...)` calls.
2. Rerun `flutter analyze` and confirm zero issues.
3. Finish decoupling cart badge updates from `CartService`.
4. Add missing centralized routes.
5. Prepare Android release package/signing config.
6. Update stale docs, especially `docs/AI_HANDOFF.md`.
