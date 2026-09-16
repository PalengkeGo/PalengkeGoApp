/**
 * Trusted private-bucket read authorization (audit 2026-09-13 C1).
 *
 * Private buckets (kyc, license) hold KYC permit photos and license renewal
 * documents — sensitive PII. The anon key has NO select policy anymore, so
 * short-lived read URLs are minted HERE instead of client-side:
 *
 *   1. verify the caller's Firebase ID token (bearerUid),
 *   2. allow the document's owner (path prefix == uid) OR an admin
 *      (users/{uid}.role == 'admin' — the MEPO portal review flow),
 *   3. mint a 1-hour signed URL with the service role key.
 *
 * Replaces the old 30-day createSignedUrl-from-client flow whose URLs were
 * persisted in Firestore — leak-amplifying bearer URLs are gone; anything
 * that leaks now expires within the hour.
 */

import { bearerUid, err, handle, roleOf } from '../_shared/backend.ts'

const PRIVATE_BUCKETS: Record<string, { ext: string[] }> = {
  kyc: { ext: ['jpg', 'jpeg', 'png', 'webp', 'pdf'] },
  license: { ext: ['jpg', 'jpeg', 'png', 'webp', 'pdf'] },
}

const READ_SIGN_TTL_SECONDS = 60 * 60 // 1 hour

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
      throw err('failed-precondition', 'Storage service is not configured')
    }

    const uid = await bearerUid(req)

    const body = await req.json().catch(() => ({}))
    const bucket: string = typeof body.bucket === 'string' ? body.bucket : ''
    const path: string = typeof body.path === 'string' ? body.path : ''

    const cfg = PRIVATE_BUCKETS[bucket]
    if (!cfg) {
      throw err('invalid-argument', 'Unknown or non-private bucket')
    }
    if (path.includes('..') || path.startsWith('/')) {
      throw err('invalid-argument', 'Invalid path')
    }
    const ext = path.split('.').pop()?.toLowerCase() ?? ''
    if (!cfg.ext.includes(ext)) {
      throw err('invalid-argument', `Extension .${ext} is not allowed in ${bucket}`)
    }

    // Owner (path prefix == own uid) or admin.
    const ownerUid = path.split('/')[0]
    if (ownerUid !== uid) {
      const role = await roleOf(uid)
      if (role !== 'admin') {
        throw err('permission-denied', 'Not your document')
      }
    }

    const signRes = await fetch(
      `${SUPABASE_URL}/storage/v1/object/sign/${bucket}/${path}`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ expiresIn: READ_SIGN_TTL_SECONDS }),
      },
    )
    if (!signRes.ok) {
      throw err('internal', `Could not sign the object (${signRes.status})`)
    }
    const signed = await signRes.json()
    const relativeUrl: unknown = signed?.signedURL
    if (typeof relativeUrl !== 'string') {
      throw err('internal', 'Unexpected storage sign response')
    }

    return {
      url: `${SUPABASE_URL}/storage/v1${relativeUrl}`,
      expiresIn: READ_SIGN_TTL_SECONDS,
    }
  }),
)
