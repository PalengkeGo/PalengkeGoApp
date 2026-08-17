# PalengkeGo QA Pipeline

Date: 2026-06-11

## Purpose

This document explains how PalengkeGo is tested, what the current CI pipeline does, what CD means later, and how bugs should be documented for QA and portfolio purposes.

## Current Status

Current pipeline status:

- CI is started.
- CD is not started yet.
- Backend testing is not started yet.
- Manual QA is still required for real user-flow confidence.

The current GitHub Actions workflow is:

```text
.github/workflows/flutter-ci.yml
```

It is a CI workflow. It is not a full deployment workflow.

## CI vs CD

## CI: Continuous Integration

CI checks whether new code can safely integrate into the project.

For PalengkeGo, CI currently answers:

- Can dependencies install on a clean machine?
- Does static analysis pass?
- Do automated tests pass?
- Can Android debug APK build?
- Can coverage be generated?

Current CI commands:

```bash
flutter pub get
flutter analyze
flutter test --coverage
flutter build apk --debug
```

If these pass, the frontend baseline is healthy enough for a pull request review.

## CD: Continuous Delivery / Deployment

CD packages and delivers the app automatically.

PalengkeGo is not ready for CD yet because:

- release signing is not configured;
- backend is not implemented;
- production environment config is not finalized;
- Play Store/internal testing lane is not set up;
- real Firebase/Supabase/PayMongo integration is not finished;
- human testing groups are not active yet.

CD should be added later, when the app is ready to test with real people or distribute release builds.

## Current GitHub Actions Workflow

The current workflow runs on:

- pull requests;
- pushes to `main`;
- pushes to `master`.

Workflow file:

```text
.github/workflows/flutter-ci.yml
```

## Workflow Steps

### 1. Checkout

```yaml
uses: actions/checkout@v4
```

Downloads the repository into GitHub's temporary runner.

QA meaning:

The pipeline tests only what is committed, not files that exist only on a developer's machine.

### 2. Set Up Java

```yaml
uses: actions/setup-java@v4
```

Installs Java 17 for Android/Gradle builds.

QA meaning:

The Android build environment is consistent.

### 3. Set Up Flutter

```yaml
uses: subosito/flutter-action@v2
```

Installs Flutter stable and enables package caching.

QA meaning:

The app is tested in a clean Flutter environment.

### 4. Flutter Version

```bash
flutter --version
```

Prints the Flutter version used by CI.

QA meaning:

If builds fail later, the toolchain version is visible in logs.

### 5. Install Dependencies

```bash
flutter pub get
```

Installs dependencies from `pubspec.yaml` and `pubspec.lock`.

QA meaning:

Confirms the dependency graph resolves on a clean machine.

### 6. Analyze

```bash
flutter analyze
```

Runs static analysis.

This catches:

- type errors;
- missing imports;
- invalid APIs;
- deprecated APIs;
- lint issues;
- many compile-time mistakes.

QA meaning:

This is the fastest quality gate. If analyze fails, the code should not be merged.

### 7. Test With Coverage

```bash
flutter test --coverage
```

Runs automated tests and creates:

```text
coverage/lcov.info
```

QA meaning:

This checks regression safety. If a behavior has a test, CI can catch when that behavior breaks.

Current coverage is published but not enforced with a required percentage yet.

### 8. Build Debug APK

```bash
flutter build apk --debug
```

Builds an Android debug APK.

QA meaning:

Passing tests are not enough. This step proves the app can actually compile into an installable Android build.

### 9. Upload Coverage Artifact

Uploads:

```text
coverage/lcov.info
```

QA meaning:

The coverage file can be downloaded from the GitHub Actions run.

### 10. Upload Debug APK Artifact

Uploads:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

QA meaning:

The APK can be downloaded from the GitHub Actions run and installed for manual testing.

## What Passing CI Means

Passing CI means:

- dependency installation worked;
- analyzer found no issues;
- automated tests passed;
- coverage report was created;
- debug APK build succeeded.

Passing CI does not mean:

- the app has no bugs;
- every user flow was manually tested;
- UI is perfect on every phone size;
- backend is working;
- payments are production-ready;
- push notifications are production-ready;
- the app is ready for Play Store release.

## What Failing CI Means

If CI fails, check the failed step.

### `flutter pub get` Failed

Possible causes:

- dependency conflict;
- missing `pubspec.lock`;
- invalid `pubspec.yaml`;
- Flutter version mismatch.

QA action:

Log it as dependency/setup failure.

### `flutter analyze` Failed

Possible causes:

- broken import;
- type mismatch;
- deprecated API;
- invalid code;
- lint violation.

QA action:

Log it as static analysis failure.

### `flutter test --coverage` Failed

Possible causes:

- regression in business logic;
- widget behavior changed;
- test expectation outdated;
- async/timer issue;
- provider state issue.

QA action:

Log it as automated test regression.

### `flutter build apk --debug` Failed

Possible causes:

- Android config issue;
- Gradle issue;
- package ID/manifest issue;
- missing asset;
- plugin build issue.

QA action:

Log it as build/package failure.

## Current Automated Test Areas

Current tests cover:

- cart provider behavior;
- cart service behavior;
- order service behavior;
- order provider behavior;
- multi-vendor checkout to confirmation;
- search provider behavior;
- market repository behavior;
- recipe repository behavior;
- saved recipes provider behavior;
- favorites provider behavior;
- notification provider/service behavior;
- basic app smoke loading.

## Testing Still Needed Later

Recommended next testing additions:

- payment selection result tests;
- delivery address result tests;
- auth guard tests;
- vendor order action tests;
- vendor product stock mutation tests;
- app router invalid argument tests;
- checkout delivery vs pickup metadata tests;
- manual QA checklist for customer flows;
- manual QA checklist for vendor flows;
- screenshot/golden tests if UI visual stability becomes important.

## Future CD Plan

CD should be added after backend integration and real-user testing preparation.

Future CD stages:

### Stage 1: Release Build Artifact

Add workflow job for:

```bash
flutter build apk --release
flutter build appbundle --release
```

Requires:

- Android signing config;
- GitHub Secrets for keystore/passwords;
- version naming strategy.

### Stage 2: Internal Testing Distribution

Possible options:

- upload APK artifact for testers;
- Firebase App Distribution;
- Google Play Internal Testing.

Requires:

- release signing;
- tester group;
- release notes.

### Stage 3: Production Release

Possible future workflow:

- tag release;
- build app bundle;
- upload to Play Console;
- publish to internal/closed/production track.

Requires:

- fully tested backend;
- production secrets;
- privacy policy;
- app signing;
- store listing;
- production QA sign-off.

## Manual QA Checklist

Use this before demo or user testing.

### Customer Flow

- [ ] App opens from fresh install
- [ ] Splash screen advances
- [ ] Login screen opens when logged out
- [ ] Customer can enter main app
- [ ] Customer can browse home screen
- [ ] Customer can search vendors
- [ ] Customer can open market screen
- [ ] Customer can open vendor profile
- [ ] Customer can add product to cart
- [ ] Cart quantity updates
- [ ] Cart item selection works
- [ ] Delivery address screen opens
- [ ] Delivery address saves back to cart/checkout
- [ ] Checkout delivery flow works
- [ ] Checkout pickup flow works
- [ ] Payment method screen opens
- [ ] Cash on Delivery selection works
- [ ] Card mock selection works
- [ ] GCash placeholder is clear
- [ ] Multi-vendor checkout creates multiple orders
- [ ] Confirmation screen shows all created orders
- [ ] Order history shows new orders
- [ ] Active order tracking opens
- [ ] Completed order details open
- [ ] Reorder works for completed orders
- [ ] Recipes screen opens
- [ ] Recipe details open
- [ ] Saved recipes work
- [ ] Notifications screen opens
- [ ] Profile screen opens

### Vendor Flow

- [ ] Vendor login/demo entry works
- [ ] Vendor dashboard opens
- [ ] Vendor order list opens
- [ ] Vendor can accept order
- [ ] Vendor can reject order
- [ ] Vendor can mark order ready
- [ ] Vendor can complete order
- [ ] Customer/vendor notifications update after status change
- [ ] Vendor products screen opens
- [ ] Product search works
- [ ] Out-of-stock filter works
- [ ] Product stock toggle works
- [ ] Add product screen opens
- [ ] Vendor earnings screen opens
- [ ] Vendor profile screen opens
- [ ] Stall settings screen opens
- [ ] Vendor account screen opens
- [ ] Vendor help/support screen opens

## Bug Documentation

Use this section to document bugs found during manual QA, CI runs, tester feedback, or development.

For portfolio purposes, try to write bug reports like a QA professional: clear title, environment, steps, expected result, actual result, evidence, severity, and status.

## Bug Report Template

Copy this template for each bug.

```text
Bug ID:
Title:
Reported By:
Date Reported:

Environment:
- Device:
- OS version:
- App build/version:
- Network:
- Account type: Customer / Vendor / Both

Severity:
- Critical / High / Medium / Low

Priority:
- P0 / P1 / P2 / P3

Status:
- New / Confirmed / In Progress / Fixed / Retest / Closed / Won't Fix

Feature Area:
- Auth / Cart / Checkout / Orders / Vendor / Recipes / Notifications / Profile / CI / Backend

Preconditions:

Steps To Reproduce:
1.
2.
3.

Expected Result:

Actual Result:

Evidence:
- Screenshot/video:
- Logs:
- CI run link:

Reproducibility:
- Always / Sometimes / Once / Cannot Reproduce

Impact:

Suspected Cause:

Developer Notes:

Retest Steps:
1.
2.
3.

Retest Result:
- Pass / Fail

Closed Date:
```

## Bug Log

Add bugs below this line.

---

### Bug 001

```text
Bug ID:
Title:
Reported By:
Date Reported:

Environment:
- Device:
- OS version:
- App build/version:
- Network:
- Account type:

Severity:

Priority:

Status:

Feature Area:

Preconditions:

Steps To Reproduce:
1.
2.
3.

Expected Result:

Actual Result:

Evidence:

Reproducibility:

Impact:

Suspected Cause:

Developer Notes:

Retest Steps:
1.
2.
3.

Retest Result:

Closed Date:
```
