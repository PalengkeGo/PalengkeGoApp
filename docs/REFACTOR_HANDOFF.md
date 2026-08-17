# PalengkeGo Refactor Handoff

Last updated: 2026-06-13

## Current Status

The frontend is in a hardened pre-backend state. It is not production/release complete, but it is now ready for disciplined CI-backed frontend stabilization and backend scaffolding preparation.

Current verified quality gate:

```powershell
flutter analyze
flutter test --coverage
flutter build apk --debug
```

Latest verified result:

- `flutter analyze`: `No issues found`.
- `flutter test --coverage`: all tests passed, `73/73`.
- `flutter build apk --debug`: built `build/app/outputs/flutter-apk/app-debug.apk`.

## Current Source-Of-Truth Docs

Use these docs first:

- `README.md`
- `docs/ARCHITECTURE_REFACTOR.md`
- `docs/BACKEND_ARCHITECTURE.md`
- `docs/QA_PIPELINE.md`

Do not use the removed backend docs:

- `docs/backend_plan_dataconnect.md`
- `docs/database_schema.md`

Those were replaced because the backend direction changed.

## Backend Direction

The backend is hybrid:

- Firebase for auth, Firestore operational data, Cloud Storage, Cloud Functions, FCM.
- Supabase Postgres for recipes, recipe ingredients, recipe joins, recommendations, and saved recipes.
- PayMongo through Cloud Functions for payment intent creation and webhook verification.

Do not use Firebase Data Connect unless the budget/hosting decision changes.

Do not use Firestore for recipe recommendation joins.

## CI Status

Basic CI exists at:

```text
.github/workflows/flutter-ci.yml
```

It runs:

```bash
flutter pub get
flutter analyze
flutter test --coverage
flutter build apk --debug
```

It uploads:

- `coverage/lcov.info`
- `build/app/outputs/flutter-apk/app-debug.apk`

This is CI only. CD/release distribution is intentionally not implemented yet.

## Android Status

Current Android identity:

- namespace: `com.palengkego.app`
- applicationId: `com.palengkego.app`
- app label: `PalengkeGo`

Release signing is not finalized. Do not treat release builds as Play Store-ready.

## Git Hygiene Status

Important:

- `pubspec.lock` is no longer ignored and should be committed.
- `docs/BACKEND_ARCHITECTURE.md` is allowlisted.
- `docs/QA_PIPELINE.md` is allowlisted.
- The worktree is still large and dirty. Stage intentionally.

Recommended commit groups:

1. CI/docs/backend architecture:
   - `.github/workflows/flutter-ci.yml`
   - `README.md`
   - `.gitignore`
   - `docs/BACKEND_ARCHITECTURE.md`
   - `docs/QA_PIPELINE.md`
   - deleted stale backend docs
   - `pubspec.lock`
2. Android identity:
   - `android/app/build.gradle.kts`
   - `android/app/src/main/AndroidManifest.xml`
   - `android/app/src/main/kotlin/com/example/palengkego/MainActivity.kt`
3. Frontend hardening:
   - typed delivery address result
   - typed payment selection result
   - debug print removal
   - `AppConfig` backend flag alignment
4. Broader frontend completion work:
   - providers
   - notification service
   - vendor stall/orders providers
   - order/payment/fulfillment domain updates
   - related tests

Do not make one giant commit if review quality matters.

## Completed Since Earlier Handoff

- Analyzer cleanup completed.
- Direct `globalCart` / `globalOrders` presentation usage has been removed from active app code.
- `customer_preferences_service.dart` was removed in favor of provider-backed preferences.
- `vendor_stall_controller.dart` was removed in favor of provider-backed vendor stall state.
- Notification service/provider was added.
- Search provider was added.
- Favorites provider was added.
- Preferences provider was added.
- Vendor stall/orders providers were added.
- Order domain now includes payment and fulfillment concepts.
- Multi-vendor checkout confirmation is covered by a widget test.
- Delivery address route result is typed as `DeliveryAddress`.
- Payment route result is typed as `PaymentSelectionResult`.
- Card route result is typed as `CardSelectionData`.
- Add-card flow no longer returns full card number or CVV through navigation.
- Add-to-cart bottom sheet now accepts typed `VendorProduct` data instead of UI-level product maps.
- New checkout orders intentionally start as `pending` until the vendor accepts them.
- Vendor order action provider tests cover accept, reject, ready, and complete transitions.
- Auth guard widget tests cover logged-out and logged-in rendering.
- Router tests cover invalid route arguments and unknown routes.
- Android debug APK builds under the new package identity.
- Basic GitHub Actions Flutter CI was added.
- QA pipeline and bug documentation template were added.

## Known Remaining Frontend Risks

### Mock Data Still Uses Maps

File:

- `lib/core/mock/mock_data.dart`

This is acceptable temporarily because repositories still convert mock maps into typed models. It should shrink as backend adapters are introduced.

### Some Serialization Helpers Still Return Maps

Examples:

- recipe `toMap` / `toDetailsMap`
- market model `fromMap` / `toMap`
- vendor product `toMap`

This is acceptable while bridging mock/backend adapter data, but avoid passing these maps through UI navigation.

### GCash Is Still Placeholder

File:

- `lib/features/checkout/presentation/pages/payment_methods_screen.dart`

GCash should remain a clear placeholder until PayMongo Cloud Functions exist. Do not fake a successful production GCash payment.

### Backend Is Not Wired Yet

Current app still uses mock repositories/services. Backend work should start only after the frontend hardening commits are clean and CI passes on GitHub.

## Recommended Next Work

1. Commit/stage current frontend hardening and docs in logical groups.
2. Push branch and confirm GitHub Actions CI passes.
3. Push branch and confirm GitHub Actions CI passes.
4. Add backend dependencies only after the CI baseline is green on GitHub.
5. Start backend Phase 1:
   - Firebase project config;
   - Firebase Auth repository adapter;
   - Firestore profile repository adapter.

## Quality Gate Before Backend Work

Run:

```powershell
flutter pub get
flutter analyze
flutter test --coverage
flutter build apk --debug
```

Expected:

- analyzer clean;
- tests all pass;
- debug APK builds;
- no debug order/payment logs in test output;
- no secrets added to source control.
