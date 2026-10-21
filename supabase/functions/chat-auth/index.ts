import { cert, getApps, initializeApp } from 'npm:firebase-admin@12.7.0/app'
import { getAuth } from 'npm:firebase-admin@12.7.0/auth'
import { bearerUid, err, handle, isBlocked, roleOf } from '../_shared/backend.ts'
import { rateLimit } from '../_shared/security.ts'

// Supabase Realtime expects the authenticated Postgres role in Firebase JWTs.
// Provision only the verified caller, preserving unrelated Firebase claims.
Deno.serve((req: Request) => handle(req, async (req) => {
  const uid = await bearerUid(req)
  if (!await roleOf(uid) || await isBlocked(uid)) {
    throw err('permission-denied', 'Chat access denied')
  }
  await rateLimit(uid, 'chat-auth', 10)
  if (!getApps().length) {
    const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!raw) throw err('internal', 'Chat authentication is not configured')
    initializeApp({ credential: cert(JSON.parse(raw)) })
  }
  const auth = getAuth()
  const user = await auth.getUser(uid)
  if (user.customClaims?.role !== 'authenticated') {
    await auth.setCustomUserClaims(uid, { ...user.customClaims, role: 'authenticated' })
  }
  return { refreshToken: true }
}))
