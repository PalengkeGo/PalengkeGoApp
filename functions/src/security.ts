/**
 * Shared hardening for the trusted backend.
 *
 * 1) App Check enforcement toggle
 *    Callables are declared with `enforceAppCheck: APP_CHECK_ENFORCED`. The
 *    value is read at cold start from the APP_CHECK_ENFORCED env var:
 *
 *      firebase functions:config:set appcheck.enforced=true
 *
 *    Keep it OFF until the Firebase console has Play Integrity (Android) /
 *    App Attest (iOS) configured AND the app ships tokens (lib activates
 *    firebase_app_check at startup). Flip to true once live.
 *
 * 2) Per-user sliding-window rate limiter
 *    Firestore-backed (rateLimits/{action}_{uid}) so it survives multiple
 *    function instances. Pure window math is exported for unit tests.
 */
import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';

export const APP_CHECK_ENFORCED = process.env.APP_CHECK_ENFORCED === 'true';

const db = admin.firestore();

const WINDOW_MS = 60 * 1000;

export interface RateLimitDecision {
  allowed: boolean;
  windowStart: number;
  count: number;
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
    return { allowed: true, windowStart: nowMs, count: 1 };
  }
  if (count >= maxPerMinute) {
    return { allowed: false, windowStart, count };
  }
  return { allowed: true, windowStart, count: count + 1 };
}

/**
 * Enforces a per-user, per-action limit. Must run AFTER authentication so the
 * uid is attacker-controlled but attributable; throws `resource-exhausted`
 * when the caller exceeds the limit.
 */
export async function rateLimit(
  uid: string,
  action: string,
  maxPerMinute: number,
): Promise<void> {
  const ref = db.collection('rateLimits').doc(`${action}_${uid}`);
  const now = Date.now();

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const prev = snap.exists ? snap.data()! : undefined;
    const decision = rateLimitDecision(
      prev?.windowStart as number | undefined,
      prev?.count as number | undefined,
      now,
      maxPerMinute,
    );
    if (!decision.allowed) {
      throw new HttpsError(
        'resource-exhausted',
        'Too many requests — please try again shortly',
      );
    }
    tx.set(ref, {
      windowStart: decision.windowStart,
      count: decision.count,
    });
  });
}
