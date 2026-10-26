import { err, handle, roleOf, verifyFirebaseToken, supabase } from '../_shared/backend.ts'
import { rateLimit } from '../_shared/security.ts'

Deno.serve((req: Request) => handle(req, async (request) => {
  if (request.method !== 'POST') throw err('invalid-argument', 'POST required')
  const header = request.headers.get('Authorization') ?? ''
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : ''
  if (!token) throw err('unauthenticated', 'Sign in required')

  let uid: string
  try {
    uid = (await verifyFirebaseToken(token)).uid
  } catch {
    throw err('unauthenticated', 'Sign in required')
  }
  if (!await roleOf(uid)) throw err('permission-denied', 'Account not found')
  await rateLimit(uid, 'account-device-token', 30)

  const body = await request.json() as Record<string, unknown>
  if (typeof body.token !== 'string' || body.token.length < 20 || body.token.length > 4096) {
    throw err('invalid-argument', 'A valid device token is required')
  }
  const platforms = ['android', 'iOS', 'linux', 'macOS', 'windows', 'fuchsia']
  if (typeof body.platform !== 'string' || !platforms.includes(body.platform)) {
    throw err('invalid-argument', 'Unsupported device platform')
  }

  const { error } = await supabase.from('account_device_tokens').upsert({
    user_id: uid,
    token: body.token,
    platform: body.platform,
    updated_at: new Date().toISOString(),
  }, { onConflict: 'token' })
  if (error) throw error
  return { registered: true }
}))
