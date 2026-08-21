/**
 * Shared hardening for the trusted backend (Supabase Edge Functions).
 *
 * Ported from functions/src/security.ts. PURE module (errors.ts only): the
 * Firestore handle is passed in so nothing here imports firebase — jest-testable.
 *
 * NOTE: App Check has no Supabase Edge Function equivalent. The auth boundary
 * is Firebase ID-token verification (bearerUid in backend.ts); Firestore
 * security rules still gate all client reads/writes.
 */

import { err } from './errors.ts'

const WINDOW_MS = 60 * 1000

export interface RateLimitDecision {
  allowed: boolean
  windowStart: number
  count: number
}

/**
 * Pure sliding-window decision. When the window has expired the request is
 * allowed and a fresh window starts; otherwise the counter is incremented and
 * requests beyond [maxPerMinute] are denied.
 */
export function rateLimitDecision(
  windowStart: number | undefined,
  count: number | undefined,
  nowMs: number,
  maxPerMinute: number,
  windowMs: number = WINDOW_MS,
): RateLimitDecision {
  if (
    windowStart === undefined ||
    count === undefined ||
    nowMs - windowStart >= windowMs
  ) {
    return { allowed: true, windowStart: nowMs, count: 1 }
  }
  if (count >= maxPerMinute) {
    return { allowed: false, windowStart, count }
  }
  return { allowed: true, windowStart, count: count + 1 }
}

/**
 * Enforces a per-user, per-action limit. Must run AFTER authentication so the
 * uid is attacker-controlled but attributable; throws an ApiError
 * (`resource-exhausted`) when the caller exceeds the limit.
 */
export async function rateLimit(
  db: any,
  uid: string,
  action: string,
  maxPerMinute: number,
): Promise<void> {
  const ref = db.collection('rateLimits').doc(`${action}_${uid}`)
  const now = Date.now()

  await db.runTransaction(async (tx: any) => {
    const snap = await tx.get(ref)
    const prev = snap.exists ? snap.data()! : undefined
    const decision = rateLimitDecision(
      prev?.windowStart as number | undefined,
      prev?.count as number | undefined,
      now,
      maxPerMinute,
    )
    if (!decision.allowed) {
      throw err('resource-exhausted', 'Too many requests — please try again shortly')
    }
    tx.set(ref, {
      windowStart: decision.windowStart,
      count: decision.count,
    })
  })
}
