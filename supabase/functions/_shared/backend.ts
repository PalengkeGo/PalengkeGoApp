/**
 * Firebase Admin glue for the Supabase Edge Functions.
 *
 * Supabase runs Deno, so firebase-admin is pulled via an npm: specifier. The
 * service account JSON must be stored in the Supabase secret
 * `FIREBASE_SERVICE_ACCOUNT` (the whole JSON document, one line). Auth on the
 * trusted path: the Flutter app sends `Authorization: Bearer <Firebase ID
 * token>`; every callable-style function verifies it here — Supabase's own
 * JWT check is disabled (verify_jwt = false in config.toml).
 */

import * as admin from 'npm:firebase-admin@^12.7.0'

const serviceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
if (!serviceAccount) {
  throw new Error('FIREBASE_SERVICE_ACCOUNT secret is not set')
}

const app = admin.initializeApp({ credential: admin.credential.cert(JSON.parse(serviceAccount)) })

export const db = admin.firestore(app)
export const auth = admin.auth(app)
export const FieldValue = admin.firestore.FieldValue
export const Timestamp = admin.firestore.Timestamp

import { ApiError, err, HTTP_STATUS } from './errors.ts'
// Re-exported so every edge function can import everything from backend.ts.
export { ApiError, err, HTTP_STATUS } from './errors.ts'

/** Serializes fn's result as JSON; maps ApiError → status + {error:{code,message}}. */
export async function handle(
  req: Request,
  fn: (req: Request) => Promise<unknown>,
): Promise<Response> {
  try {
    const result = await fn(req)
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (e) {
    if (e instanceof ApiError) {
      return new Response(
        JSON.stringify({ error: { code: e.code, message: e.message } }),
        { status: HTTP_STATUS[e.code] ?? 500, headers: { 'Content-Type': 'application/json' } },
      )
    }
    console.error(e)
    return new Response(
      JSON.stringify({ error: { code: 'internal', message: 'Internal error' } }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
}

/** Verifies the Firebase ID token from the Authorization header; returns the uid. */
export async function bearerUid(
  req: Request,
  requireEmailVerified = false,
): Promise<string> {
  const header = req.headers.get('Authorization') ?? ''
  const token = header.startsWith('Bearer ') ? header.slice('Bearer '.length).trim() : ''
  if (!token) {
    throw err('unauthenticated', 'Sign in required')
  }
  try {
    const decoded = await auth.verifyIdToken(token)
    // Server-side email-verification gate (customers registering by
    // email/password must verify before ordering; Google sign-in accounts
    // always carry email_verified = true, so they pass naturally).
    if (requireEmailVerified && !decoded.email_verified) {
      throw err('failed-precondition', 'Verify your email before placing orders')
    }
    return decoded.uid
  } catch (e) {
    if (e instanceof ApiError) throw e
    throw err('unauthenticated', 'Sign in required')
  }
}

export async function roleOf(uid: string): Promise<string | null> {
  const snap = await db.collection('users').doc(uid).get()
  return snap.exists ? (snap.data()?.role as string | null) : null
}

/** True when the user doc explicitly marks the account blocked. */
export async function isBlocked(uid: string): Promise<boolean> {
  const snap = await db.collection('users').doc(uid).get()
  return snap.exists ? snap.data()?.isBlocked === true : false
}

export async function stallOwnerUid(stallId: string): Promise<string | null> {
  const snap = await db.collection('vendorStalls').doc(stallId).get()
  return snap.exists ? (snap.data()?.ownerUid as string | null) : null
}

export function assertRole(role: string | null, expected: string[]): void {
  if (!role || !expected.includes(role)) {
    throw err('permission-denied', 'You do not have permission for this operation')
  }
}
