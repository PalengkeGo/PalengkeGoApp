/**
 * Trusted storage upload authorization (audit 2026-09-13 C1 + M1).
 *
 * The anon key has NO insert/select policies on any bucket (see
 * supabase/migrations/20260914000000_lock_down_storage_buckets.sql), so the
 * app cannot upload directly anymore. Instead the client calls this function
 * with its Firebase ID token; the function:
 *
 *   1. verifies the token (bearerUid — Firebase Admin),
 *   2. enforces the bucket allowlist and `{uid}/...` path ownership,
 *   3. enforces the per-bucket extension allowlist (mirrors the old
 *      storage.rules — audit S5),
 *   4. mints a SHORT-LIVED (10 min) signed upload URL with the service role
 *      key and returns it.
 *
 * The client then PUTs the file bytes straight to Storage using the returned
 * URL + token. The bucket's file_size_limit and allowed_mime_types are still
 * enforced by the Storage API itself on that PUT, so the 2026-08-23 caps
 * (8 MB stalls / 5 MB profiles / 15 MB kyc+license, images [+pdf]) remain in
 * force server-side.
 */

import { bearerUid, err, handle } from '../_shared/backend.ts'

interface BucketCfg {
  ext: string[]
}

const BUCKETS: Record<string, BucketCfg> = {
  stalls: { ext: ['jpg', 'jpeg', 'png', 'webp'] },
  profiles: { ext: ['jpg', 'jpeg', 'png', 'webp'] },
  kyc: { ext: ['jpg', 'jpeg', 'png', 'webp', 'pdf'] },
  license: { ext: ['jpg', 'jpeg', 'png', 'webp', 'pdf'] },
}

const UPLOAD_SIGN_TTL_SECONDS = 10 * 60

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

    const cfg = BUCKETS[bucket]
    if (!cfg) {
      throw err('invalid-argument', 'Unknown bucket')
    }
    // Path ownership: every bucket's layout is `{uid}/...` (stallId ==
    // ownerUid for `stalls`), so the object must live under the caller's uid.
    if (!path.startsWith(`${uid}/`)) {
      throw err('permission-denied', 'Path must be scoped to your own uid')
    }
    if (path.includes('..') || path.startsWith('/')) {
      throw err('invalid-argument', 'Invalid path')
    }
    const ext = path.split('.').pop()?.toLowerCase() ?? ''
    if (!cfg.ext.includes(ext)) {
      throw err('invalid-argument', `Extension .${ext} is not allowed in ${bucket}`)
    }

    // Service role bypasses RLS — this is the ONLY path to Storage now.
    const signRes = await fetch(
      `${SUPABASE_URL}/storage/v1/object/upload/sign/${bucket}/${path}`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ expiresIn: UPLOAD_SIGN_TTL_SECONDS }),
      },
    )
    if (!signRes.ok) {
      throw err('internal', `Could not sign the upload (${signRes.status})`)
    }
    const signed = await signRes.json()
    const relativeUrl: unknown = signed?.url
    const token: unknown = signed?.token
    if (typeof relativeUrl !== 'string' || typeof token !== 'string') {
      throw err('internal', 'Unexpected storage sign response')
    }

    return {
      uploadUrl: `${SUPABASE_URL}/storage/v1${relativeUrl}`,
      token,
      path,
      expiresIn: UPLOAD_SIGN_TTL_SECONDS,
    }
  }),
)
