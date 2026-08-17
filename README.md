# PalengkeGo

[![CI](https://github.com/fragi/PalengkeGoAPP/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/fragi/PalengkeGoAPP/actions/workflows/flutter-ci.yml)

A Flutter mobile app for local Filipino public markets (palengke). It connects customers and vendors in one ecosystem: customers browse stalls, compare fresh goods, build carts, check out, and track orders; vendors manage stall details, products, stock state, orders, and earnings.

## Features

### For Customers

- Browse stalls and products by category
- Search and filter market vendors
- Build shopping carts and checkout with delivery or pickup
- Select delivery addresses and payment methods
- Track order status
- View order history and reorder past items
- Browse recipes and save favorites
- Receive in-app notifications for order and promo updates

### For Vendors

- Manage stall profile and open/closed state
- Add, edit, and remove product listings
- Track stock state
- View incoming orders and update preparation status
- Monitor earnings and sales summaries
- Receive vendor-facing notifications

## Tech Stack

- **Framework:** Flutter 3.x
- **Language:** Dart
- **Primary Target:** Android
- **Secondary Target:** Web preview/testing
- **State Management:** Riverpod providers/notifiers with mock repositories during frontend hardening
- **Navigation:** Centralized named routes with typed route arguments for critical flows
- **Backend Plan:** Hybrid Firebase + Supabase
- **Firebase Scope:** Auth, Firestore operational data, Cloud Storage, Cloud Functions, FCM
- **Supabase Scope:** Postgres recipe database, recipe ingredients, joins, recommendations, saved recipes
- **Payments:** PayMongo through Cloud Functions

## Project Structure

```text
lib/
  core/
    config/       Environment and public compile-time config
    mock/         Temporary mock data backing repositories
    navigation/   App routes, route args, router
    services/     Transitional local services
    theme/        App-wide theme
    utils/        Focused helpers
    widgets/      Cross-feature widgets
  features/
    auth/
    cart/
    checkout/
    home/
    main/
    market/
    notifications/
    onboarding/
    orders/
    profile/
    recipes/
    vendors/
```

Feature folders should move toward:

```text
domain/        Typed models, enums, pure business concepts
data/          Mock repositories now, backend adapters later
application/   Riverpod providers/notifiers/controllers
presentation/  Pages and widgets
```

## Quick Start

### Prerequisites

- Flutter SDK 3.x
- Android Studio or VS Code with Flutter/Dart extensions
- Android emulator or physical Android device
- Git

### Install

```bash
flutter pub get
flutter doctor
```

### Run

```bash
flutter run
flutter run -d chrome
flutter devices
```

### Build

```bash
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
```

Release signing is not finalized yet. Do not treat release build commands as Play Store-ready until signing secrets and package release policy are configured.

## Quality Gates

Run these before pushing frontend changes:

```bash
flutter pub get
flutter analyze
flutter test --coverage
flutter build apk --debug
```

The GitHub Actions workflow in `.github/workflows/flutter-ci.yml` runs the same baseline on pushes and pull requests to `main` or `master`.

CI artifacts:

- `coverage-lcov`: line coverage report from `coverage/lcov.info`
- `app-debug-apk`: debug Android APK from `build/app/outputs/flutter-apk/app-debug.apk`

Current CI intent:

- block analyzer regressions
- block failing tests
- prove the Android debug APK still builds
- publish coverage without enforcing a percentage threshold yet

## Configuration

Public compile-time config uses `--dart-define`:

```bash
flutter run --dart-define=APP_ENV=development
flutter run --dart-define=FIREBASE_ENABLED=false
flutter run --dart-define=SUPABASE_URL=https://example.supabase.co
flutter run --dart-define=SUPABASE_ANON_KEY=public-anon-key
flutter run --dart-define=PAYMONGO_PUBLIC_KEY=pk_test_xxx
```

Never commit:

- PayMongo secret keys
- Firebase service account JSON
- webhook signing secrets
- Supabase service role key
- local Firebase/Supabase secret files

## Backend Direction

The backend source of truth is [docs/BACKEND_ARCHITECTURE.md](docs/BACKEND_ARCHITECTURE.md).

Summary:

- Use Firebase for auth, operational app data, images, notifications, Cloud Functions, and payment side effects.
- Use Supabase Postgres for recipes because recipe recommendations need relational joins.
- Do not use Firebase Data Connect unless the budget/hosting decision changes.
- Do not use Firestore for recipe recommendation joins.
- Do not call Firebase, Supabase, or PayMongo directly from widgets.
- Route backend access through repositories and Riverpod providers.

## Development Workflow

1. Run `flutter analyze` before starting if you need a clean baseline.
2. Make small, focused changes.
3. Keep UI in `presentation/`, state orchestration in `application/`, repositories in `data/`, and models in `domain/`.
4. Prefer typed route results over `Map<String, dynamic>` for cross-screen data.
5. Run the quality gates before pushing.
6. Test critical customer and vendor flows manually on Android before release/demo checkpoints.

## Code Standards

- Use `const` constructors where practical.
- Prefer `SizedBox` over `Container` for spacing.
- Do not use `BuildContext` across async gaps without a `mounted` guard.
- Keep analyzer output clean.
- Keep backend SDK calls out of widgets.
- Keep mock behavior behind repository/provider boundaries.
- Do not store raw card data in Flutter state, navigation results, logs, or source files.

## Platform Support

| Platform | Status | Notes |
| --- | --- | --- |
| Android | Primary | Main target for demo/build verification |
| Web | Preview | Useful for quick UI checks |
| iOS | Not supported | No macOS build environment |
| Windows | Not supported | Desktop not in project scope |
| Linux | Not supported | Desktop not in project scope |
| macOS | Not supported | Desktop not in project scope |

## Troubleshooting

- **`flutter analyze` fails:** Fix every issue before opening a PR.
- **Tests fail locally:** Run the failing test file first, then the full suite.
- **Debug APK fails:** Check Android package config, Gradle output, and Java/Flutter versions.
- **Images do not load:** Confirm assets are listed in `pubspec.yaml` and restart the app.
- **Firebase auth errors:** Firebase is not wired yet. Current auth uses mock repositories/providers.
- **Supabase recipe errors:** Supabase is not wired yet. Current recipes use mock repositories.
- **PayMongo payment errors:** Payment flows are mocked. Real PayMongo work must go through Cloud Functions.

## Important Docs

- [Architecture Refactor](docs/ARCHITECTURE_REFACTOR.md)
- [Backend Architecture](docs/BACKEND_ARCHITECTURE.md)
- [Refactor Handoff](docs/REFACTOR_HANDOFF.md)
- [Audit Findings](docs/audit-findings-and-issues-to-address-2026-06-04.md)

## License

This project is for academic/thesis purposes. Contact the maintainers for reuse or distribution questions.
