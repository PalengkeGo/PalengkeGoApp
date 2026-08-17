# PalengkeGo Backend Architecture

Date: 2026-06-13

This document is the backend source of truth for PalengkeGo after the frontend hardening pass. The app is moving to a hybrid backend:

- Firebase remains the main app backend for auth, app user data, vendor operations, orders, notifications, files, and Cloud Functions.
- Supabase/Postgres owns the recipe database because recipes need relational joins, ingredient mapping, search-friendly tables, and future recommendation logic.
- PayMongo is accessed only through trusted backend code. Flutter must never hold PayMongo secret keys or finalize trusted payment state by itself.

## Current Product Behavior To Preserve

New checkout orders start as `OrderStatus.pending` for both pickup and delivery.

Reason:

- The customer places an order.
- The order appears in the vendor UI as pending.
- The vendor accepts the order.
- Accepting moves the order forward to `OrderStatus.preparing`.
- Later actions move it to `ready`, `completed`, or `cancelled`.

This is intentional for the responsive customer/vendor flow. Do not restore the older rule where delivery orders start as `confirmed`.

Great quality looks like this:

- `OrderService.placeOrders(...)` always creates new orders as `pending`.
- Vendor actions are the only path that moves a new order out of `pending`.
- Tests describe pending-until-accepted behavior clearly.
- Customer UI and vendor UI both react to the same order state source.

## Backend Ownership Map

### Firebase

Use Firebase for:

- Firebase Authentication.
- customer profiles.
- vendor profiles and stall records.
- vendor products and inventory status.
- carts if a persisted cart is needed.
- orders and order status changes.
- notifications and FCM device tokens.
- uploaded images.
- payment references, payment status, and webhook results.
- Cloud Functions for trusted server-side actions.

Firebase is the best fit for the app's operational data because most entities are document-style and need realtime UI updates.

### Supabase

Use Supabase for:

- recipes.
- recipe ingredients.
- recipe steps.
- recipe tags.
- recipe categories.
- ingredient-to-market-product matching.
- saved recipe relations if relational querying becomes important.
- recipe search metadata.

Supabase is the best fit for recipes because recipe data is relational. Firestore is NoSQL and would force awkward duplicated arrays for ingredients, steps, joins, and recommendation queries. Firebase Data Connect also uses Postgres, but it is paid, so the current budget-friendly path is Supabase.

### PayMongo

Use PayMongo only through Cloud Functions:

- create payment intent.
- create checkout/session if needed.
- receive webhook events.
- verify webhook signatures.
- update payment status.
- connect payment result to an order.

Flutter may use a PayMongo public key only where the SDK requires it. Flutter must never contain the secret key.

## App Layers

Flutter should not call Firebase or Supabase directly from widgets.

Expected layering:

- widgets call Riverpod providers.
- providers call repositories/services.
- repositories call Firebase, Supabase, or mock adapters.
- domain models stay typed.
- UI route results stay typed.

Great quality looks like this:

- A widget receives a `VendorProduct`, not `Map<String, dynamic>`.
- A checkout route returns `PaymentSelectionResult`, not raw card data.
- Address routes return `DeliveryAddress`, not loosely shaped maps.
- Backend-specific parsing lives in repository/data files.
- The UI does not know whether data came from mock data, Firebase, or Supabase.

## Environments And Configuration

Use compile-time configuration with `--dart-define`.

Current intended keys:

- `APP_ENV`
- `FIREBASE_ENABLED`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `PAYMONGO_PUBLIC_KEY`

Recommended future keys:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_MESSAGING_SENDER_ID`
- `API_REGION`
- `SENTRY_DSN` or similar crash reporting key, if added.

Rules:

- Missing production config should fail closed.
- Development may run with mock adapters.
- Production must not silently fall back to mocks.
- Secrets must not be committed.
- `.env` files must stay ignored unless they are example files.

Great quality looks like this:

- `APP_ENV=prod` refuses to start if required backend config is missing.
- `APP_ENV=dev` can use mock data intentionally.
- README documents the exact local run command.
- CI runs with safe mock/test values and no real secrets.

## Firebase Data Model Draft

### users/{uid}

Purpose: shared user identity and role metadata.

Fields:

- `uid`
- `email`
- `displayName`
- `phoneNumber`
- `role`: `customer`, `vendor`, or `admin`
- `photoUrl`
- `createdAt`
- `updatedAt`
- `disabled`

Security:

- User can read and update limited own profile fields.
- User cannot grant themselves vendor/admin role.
- Admin-only role changes.

### customerProfiles/{uid}

Purpose: customer-specific profile details.

Fields:

- `uid`
- `fullName`
- `phoneNumber`
- `defaultAddressId`
- `preferences`
- `createdAt`
- `updatedAt`

Security:

- Customer can read/write own profile.
- Vendor cannot read customer profile except order delivery fields needed for accepted orders.

### customerProfiles/{uid}/addresses/{addressId}

Fields:

- `label`
- `primaryAddress`
- `streetAddress`
- `city`
- `province`
- `postalCode`
- `landmark`
- `latitude`
- `longitude`
- `isDefault`
- `createdAt`
- `updatedAt`

Security:

- Customer can manage own addresses.
- Vendor receives only the selected order delivery address when needed.

### vendorStalls/{stallId}

Fields:

- `ownerUid`
- `name`
- `registeredName`
- `category`
- `stallNumber`
- `description`
- `phoneNumber`
- `status`: `draft`, `pendingReview`, `approved`, `rejected`, `suspended`
- `isOpen`
- `operatingHours`
- `avatarUrl`
- `coverImageUrl`
- `createdAt`
- `updatedAt`

Security:

- Owner can edit draft and approved stall fields.
- Owner cannot approve their own stall.
- Public can read approved active stalls.
- Admin can review, suspend, or reject.

### vendorProducts/{productId}

Fields:

- `vendorId`
- `ownerUid`
- `name`
- `description`
- `category`
- `price`
- `unitType`: `kg` or `piece`
- `availableWeights`
- `imageUrl`
- `stockStatus`
- `isActive`
- `createdAt`
- `updatedAt`

Security:

- Vendor can manage products for their own stall.
- Public can read active products for approved stalls.
- Price must be positive.
- Product name/category must be length-limited.

### orders/{orderId}

Fields:

- `orderNumber`
- `customerUid`
- `vendorId`
- `vendorName`
- `status`: `pending`, `preparing`, `ready`, `completed`, `cancelled`
- `paymentStatus`: `pending`, `paid`, `failed`, `refunded`
- `fulfillmentMethod`: `pickup` or `delivery`
- `deliveryAddressSnapshot`
- `deliveryFee`
- `serviceFee`
- `subtotal`
- `total`
- `notes`
- `placedAt`
- `acceptedAt`
- `readyAt`
- `completedAt`
- `cancelledAt`
- `updatedAt`

Security:

- Customer can create an order for themselves.
- Customer cannot set privileged status fields.
- New orders must start as `pending`.
- Vendor can read orders assigned to their stall.
- Vendor can transition assigned orders through allowed states.
- Customer can read own orders.
- Admin can read all.

Allowed status transitions:

- `pending -> preparing`
- `pending -> cancelled`
- `preparing -> ready`
- `preparing -> cancelled`
- `ready -> completed`
- `ready -> cancelled`

Do not allow:

- `completed -> pending`
- `cancelled -> preparing`
- customer-side `pending -> preparing`
- direct frontend writes to `paid`

### orders/{orderId}/items/{itemId}

Fields:

- `productId`
- `productName`
- `quantity`
- `unitPrice`
- `weight`
- `pricePerKg`
- `image`
- `lineTotal`

Security:

- Created with the order.
- Immutable after order creation except admin correction flows.

### notifications/{notificationId}

Fields:

- `recipientUid`
- `recipientRole`
- `type`
- `title`
- `body`
- `orderId`
- `read`
- `createdAt`

Security:

- Users can read/update `read` for own notifications.
- Cloud Functions create notification records.

### fcmTokens/{tokenId}

Fields:

- `uid`
- `tokenHash`
- `platform`
- `deviceLabel`
- `isActive`
- `createdAt`
- `updatedAt`
- `lastSeenAt`

Security:

- User can register and deactivate own token.
- Store token hash where possible.
- Delete tokens on logout.
- Prune stale inactive tokens with a scheduled function.

## Supabase Recipe Data Model Draft

### recipes

Columns:

- `id uuid primary key`
- `slug text unique`
- `title text`
- `description text`
- `hero_image_url text`
- `prep_minutes int`
- `cook_minutes int`
- `servings int`
- `difficulty text`
- `region text`
- `created_at timestamptz`
- `updated_at timestamptz`
- `published_at timestamptz`

### recipe_ingredients

Columns:

- `id uuid primary key`
- `recipe_id uuid references recipes(id)`
- `name text`
- `quantity numeric`
- `unit text`
- `market_category text`
- `product_match_key text`
- `sort_order int`

### recipe_steps

Columns:

- `id uuid primary key`
- `recipe_id uuid references recipes(id)`
- `instruction text`
- `timer_seconds int`
- `sort_order int`

### recipe_tags

Columns:

- `id uuid primary key`
- `name text unique`

### recipe_tag_links

Columns:

- `recipe_id uuid references recipes(id)`
- `tag_id uuid references recipe_tags(id)`

### saved_recipes

Use Firebase if saved recipes only need simple user bookmarks. Use Supabase if future relational recipe analytics matter.

If using Supabase:

- `user_id uuid/text`
- `recipe_id uuid references recipes(id)`
- `created_at timestamptz`
- primary key on `(user_id, recipe_id)`

Security:

- Public can read published recipes.
- Only service role/admin tooling can write recipes.
- Users can read/write only their own saved recipes.
- Supabase service role key must never be used in Flutter.

## Security Requirements

### Frontend Security

Required:

- Keep PayMongo secret keys out of Flutter.
- Keep Supabase service role key out of Flutter.
- Validate forms before repository calls.
- Never store raw card numbers, CVV, or full card payloads in app state.
- Display only safe card labels like brand plus last four digits.
- Use typed route result objects for payment and address flows.
- Avoid logging PII, tokens, card details, order addresses, or payment payloads.
- Use `kDebugMode` if a temporary debug log is truly needed.
- Ensure production config cannot fall back to mock data.

Recommended:

- Add app integrity checks later, such as Firebase App Check.
- Add crash reporting with PII scrubbing.
- Add network timeout handling and retry limits.
- Add a privacy-safe analytics plan before analytics is introduced.
- Add device-token cleanup on logout.

Great quality looks like this:

- Searching the repo for `print(` does not reveal user/payment/order data logs.
- Searching the repo for `sk_`, `secret`, or `service_role` finds no real secrets.
- Payment screens pass typed safe objects, not card maps.
- Backend config is read from one central config file.

### Backend Security

Required:

- Enforce Firebase Security Rules for every collection.
- Enforce Supabase RLS for user-owned recipe relations.
- Use Cloud Functions for payment creation and webhook handling.
- Verify PayMongo webhook signatures.
- Validate order status transitions server-side.
- Prevent customers from writing vendor-only status changes.
- Prevent vendors from editing other vendors' products/orders.
- Use server timestamps for trusted lifecycle fields.
- Use least-privilege service accounts.
- Rotate keys if exposed.

Recommended:

- Add rate limits for order creation and payment intent creation.
- Add idempotency keys for payment/order creation.
- Add audit logs for payment status changes and vendor order actions.
- Add scheduled cleanup for stale FCM tokens and abandoned payment intents.
- Add monitoring alerts for failed payments, webhook failures, and rule denials.

Great quality looks like this:

- A malicious client cannot create an order as another user.
- A malicious customer cannot mark their own order `paid`.
- A vendor cannot accept another vendor's order.
- A repeated PayMongo webhook does not duplicate state changes.
- Security rules are tested with emulator tests before launch.

## Cloud Functions Plan

### createPaymentIntent

Input:

- `orderId`
- selected payment method
- expected amount

Server checks:

- caller owns the order.
- order is still payable.
- amount matches server-calculated total.
- idempotency key has not already completed.

Output:

- client-safe payment intent/session information.

### paymongoWebhook

Input:

- PayMongo webhook event.

Server checks:

- valid signature.
- known event type.
- known payment reference.
- idempotent event handling.

Actions:

- update payment status.
- create notification.
- write audit log.

### onOrderCreated

Actions:

- validate server-side totals if order creation is client-assisted.
- notify vendor.
- write order event log.

### onOrderStatusChanged

Actions:

- notify customer.
- update timestamps.
- write order event log.

### pruneFcmTokens

Actions:

- deactivate stale tokens.
- remove excessive tokens per user.
- keep latest active devices.

## Repository Migration Plan

### Phase 1: Keep Mock Baseline Green

Goal:

- Keep the app testable while introducing backend adapters.

Tasks:

- Keep current mock repositories.
- Keep `flutter analyze` clean.
- Keep `flutter test --coverage` green.
- Keep debug APK building.
- Add backend interfaces before real SDK calls.

Great quality looks like this:

- Mock and backend implementations share the same repository interface.
- Tests can override providers with mock services.
- No widget imports Firebase/Supabase packages directly.

### Phase 2: Firebase Foundation

Goal:

- Add Firebase without breaking mock/dev mode.

Tasks:

- Add Firebase project config.
- Add Firebase initialization behind `FIREBASE_ENABLED`.
- Add repository implementations for auth/profile/vendor/order.
- Add emulator-friendly test setup.
- Add security rules drafts.

Great quality looks like this:

- Dev can run without Firebase when config disables it.
- Production build refuses missing Firebase config.
- Repository tests cover Firebase mapping separately from widget tests.

### Phase 3: Order And Vendor Realtime Flow

Goal:

- Make customer checkout and vendor acceptance work from shared backend state.

Tasks:

- Persist new orders as `pending`.
- Filter vendor orders by current vendor stall.
- Implement vendor accept/reject/ready/complete transitions.
- Add notification creation for order events.
- Add backend validation for legal status transitions.

Great quality looks like this:

- Customer places order and sees pending.
- Vendor sees pending without app restart.
- Vendor accepts and customer UI updates.
- Illegal transitions fail.
- Tests cover pending-to-preparing and rejected/cancelled paths.

### Phase 4: Supabase Recipes

Goal:

- Move recipe data into relational tables.

Tasks:

- Create Supabase migrations.
- Seed initial recipe data.
- Add recipe repository using Supabase client.
- Add search/filter queries.
- Add ingredient mapping for future shopping/cart features.

Great quality looks like this:

- Recipe details load from joined tables.
- Ingredients stay ordered.
- Steps stay ordered.
- Query logic lives in repository/data layer.
- Flutter UI still receives typed `Recipe` models.

### Phase 5: Payments

Goal:

- Replace frontend-only payment success with trusted payment flow.

Tasks:

- Create Cloud Function for payment intent/session.
- Store payment references on orders.
- Handle PayMongo webhooks.
- Update `paymentStatus` only from trusted backend code.
- Add failed/cancelled payment UI states.

Great quality looks like this:

- Flutter never sends a secret key.
- Flutter never directly marks an order paid.
- Webhooks are idempotent.
- Failed payments are visible and recoverable.

### Phase 6: CI/CD And Release

Goal:

- Add deployment after backend and app flows are stable.

Tasks:

- Keep Flutter CI running analyzer, tests, coverage, and debug APK.
- Add Firebase rules validation.
- Add Supabase migration validation.
- Add Cloud Functions lint/test/deploy workflow.
- Add release build workflow later.

Great quality looks like this:

- Pull requests must pass Flutter CI.
- Backend rules/migrations are validated before merge.
- CD deploys only from protected branches.
- Production deploy requires secrets stored in GitHub Actions, not committed files.

## CI And Test Strategy

Current Flutter CI should run:

- `flutter pub get`
- `flutter analyze`
- `flutter test --coverage`
- `flutter build apk --debug`
- upload coverage and debug APK artifacts

Backend CI should later add:

- Firebase rules tests.
- Cloud Functions tests.
- Supabase migration dry run.
- Supabase type generation check, if used.
- secret scanning.

Manual QA before backend:

- Customer can register/login.
- Customer can browse stalls/products.
- Customer can add kg and piece products to cart.
- Customer can checkout.
- New order appears pending.
- Vendor can accept order.
- Customer sees status update.
- Vendor can mark ready/completed.
- Notifications appear for status changes.

## Backend Anti-Patterns

Do not:

- resurrect Firebase Data Connect unless budget changes.
- build recipe joins manually in Firestore.
- store raw card numbers.
- put PayMongo secret keys in Flutter.
- put Supabase service role key in Flutter.
- call Firebase/Supabase directly from widgets.
- use `Map<String, dynamic>` as a long-term UI or navigation contract.
- let Firebase and Supabase both own the same entity.
- implement payments as frontend-only success states.
- let production silently run on mock data.
- let customers write vendor-only order statuses.

## Immediate Next Work

Before backend implementation:

1. Keep frontend quality gate green.
2. Finish remaining high-risk typed-boundary cleanup.
3. Add route/auth guard tests.
4. Add vendor order action tests for accept/reject/ready/complete.
5. Confirm docs reflect pending-until-vendor-accepts order behavior.
6. Commit frontend hardening in reviewable chunks.
7. Start Firebase/Supabase scaffolding only after the frontend baseline is stable.

Backend start checklist:

- Firebase project created.
- Supabase project created.
- Local config documented.
- No secrets committed.
- CI passing.
- Security rules draft started.
- Recipe schema migration drafted.
- Payment flow kept behind Cloud Functions.
