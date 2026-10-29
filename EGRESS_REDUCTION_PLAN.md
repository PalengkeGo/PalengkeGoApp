# Supabase egress reduction implementation plan

Date: 29 October 2026
Status: Proposed; no egress optimizations implemented by this plan.
Scope: PalengkeGoAPP-main and sibling PalengkeGo-admin.

## Objective and evidence

Reduce bytes downloaded and repeated requests while preserving complete search,
message history, active orders, moderation enforcement, and checkout validation.
The dashboard showed 5.18 GB against a 5 GB uncached quota. Highlighted days
showed substantial PostgREST and Functions traffic. This does not establish the
bandwidth attributable to a specific table or function.

Confirmed code paths:
- market_provider.dart fetches products and stall_holders with select-all.
- Catalog providers retain data in memory but watch a shared refresh signal.
- data_refresh_signal.dart refreshes on app resume; other callers include edits,
  pull-to-refresh, reviews, and order actions.
- Search, discounts, and recipe matching depend on the full in-memory catalog.
- Messaging queries retrieve conversation history; inspect both stream and fetch
  callers before changing their initial snapshot or pagination behavior.
- read-orders returns matching orders and nested items without app pagination.
- admin-portal rows() batches 500 rows internally, then combines all pages into
  one response. Internal batching does not limit client download size.
- Profile editing can save a Base64 image when a Storage upload fails.

## Phase 1: Baseline and field audit

1. Map every consumer of product, stall, message, and order fields, including
   detail screens, cart, discounts, recipe matching, admin summaries, and exports.
2. Check actual database columns and nullable values before adding projections.
3. For representative navigation sessions record request counts, response bytes,
   first-content latency, next-page latency, and cache hits. Measure both cold
   starts and repeated navigation using the same dataset and network conditions.
4. Inspect large text/image values with read-only aggregate queries. Return
   lengths/counts rather than full images, documents, or private messages.
5. Separate database, Storage, Realtime, and function measurements. Do not infer
   bandwidth from query execution time or database cache hit rate.

Acceptance: baseline and consumer map identify measured priorities; no production
writes or migrations are needed for discovery.

## Phase 2: Smaller catalog responses

1. Replace select-all with verified explicit fields needed by current consumers.
   Keep detail fields until a detail-fetch path exists; do not silently default
   missing prices, stock, ratings, images, or descriptions.
2. Move product visibility filtering to the database while preserving the current
   treatment of nullable visibility values and vendor-management access.
3. Fetch additional product/stall details by ID when opening a detail screen.
4. Keep authorization and row-level security unchanged.

Acceptance: listing cards, details, cart, prices, discounts, and recipe results
match the baseline; response bytes decrease on representative requests.

## Phase 3: Targeted refresh and image handling

1. Preserve current provider caching. Replace broad invalidation with invalidation
   of affected resources, tracing every caller of the shared signal first.
2. Apply a configurable catalog freshness interval (initial candidate: five
   minutes) on resume. Explicit refresh and successful edits bypass that interval.
3. Keep account restriction checks and active-order updates independent of catalog
   freshness. Deduplicate concurrent loads; clear user-specific state on sign-out
   and account changes. Never use client cache as checkout authority.
4. Remove remote Base64 profile-photo fallback. On upload failure retain the old
   photo, report the failure, and allow retry without losing unrelated edits.
5. Migrate existing embedded images separately: upload, verify readability and
   ownership, then replace the database value. Preserve recoverable originals
   until verified; do not log image payloads.

Acceptance: repeated navigation reuses data; explicit refresh works; moderation
and order changes remain timely; failed photo upload preserves the old image.

## Phase 4: Message pagination

1. Inspect messaging repository, providers, chat UI, and all subscription callers.
2. Load the latest 50 messages, then display them in chronological order.
3. Use a stable timestamp-plus-ID cursor to load older messages on upward scroll.
4. Preserve one effective live subscription per conversation, merge by message ID,
   and dispose subscriptions on navigation/account changes.
5. Maintain scroll position during prepends and handle reconnects, equal timestamps,
   edits/deletions, empty conversations, and messages arriving during page loads.

Acceptance: older history remains accessible without duplicates, missing records,
scroll jumps, cross-account leakage, or repeated full-history downloads.

## Phase 5: Product and order pagination

1. Add bounded pages (initial candidate: 20) with deterministic ordering and stable
   cursors. Fetch subsequent pages on demand; prefetch near the end when useful.
2. Implement server-side product search/category filtering plus dedicated discount
   and recipe queries before removing full-catalog dependencies. Preserve existing
   matching behavior, blocked-stall filtering, and category rules.
3. Separate complete relevant active-order retrieval from paginated history.
4. Add backward-compatible read-orders request parameters and response metadata;
   update repository interfaces, providers, and screens together.
5. Prevent duplicate/in-flight page requests; keep loaded items visible during
   refresh; expose retry/end-of-list states. Checkout validates current data server-side.

Acceptance: search finds products beyond page one; discounts/recipes remain
complete; all relevant active orders are shown; old orders remain reachable.

## Phase 6: Admin endpoint pagination

1. Trace every admin-portal action and corresponding admin client call.
2. Add opt-in paginated responses with narrow fields and bounded page sizes.
   Keep existing response contracts during rollout for installed clients.
3. Compute dashboard totals/counts across all authorized matching records in the
   database, never from the displayed page. Fetch detail records only on demand.
4. Keep full exports complete through a separate authorized export flow rather
   than silently truncating them. Retain audit and moderation behavior.
5. Include support-message endpoints in the audit: bounded oldest-first responses
   must not strand later messages once histories exceed their current limits.

Acceptance: page navigation, totals, account history, KYC review, moderation,
price warnings, audit records, and exports retain their meaning.

## Verification and rollout

- Add focused regression checks for fields/visibility, cursor boundaries,
  duplicate suppression, cache invalidation, failed uploads, authorization,
  complete active orders, and full-dataset admin counts.
- Run Flutter analysis and relevant repository/widget tests in each changed app;
  run isolated backend checks for changed functions/migrations.
- Test with records beyond one page, identical timestamps, null fields, and two
  accounts. Exercise slow/offline networks and reconnects.
- Compare response bytes and latency against Phase 1. Smaller payloads are
  expected to improve first load, but no speed or percentage saving is promised.
- Deploy backward-compatible backend changes first, then matching app releases.
  Verify old clients before retiring legacy behavior. Keep each phase in a
  separate commit that can be reverted without deleting stored user records.
- Validate database migrations against existing constraints/data in an isolated
  environment before any authorized production deployment.
- Optimizations reduce future traffic; they cannot undo previously counted egress.

## Completion checklist

- [ ] Baseline and field/consumer audit recorded.
- [ ] Catalog projections and detail fetching verified.
- [ ] Targeted refresh and safe image handling verified.
- [ ] Message history and live updates verified.
- [ ] Product search/discounts/recipes and order pagination verified.
- [ ] Admin counts, pages, exports, and legacy clients verified.
- [ ] Before/after bandwidth and latency results recorded.
- [ ] Deployment and rollback steps reviewed for the final changes.
