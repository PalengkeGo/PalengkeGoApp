import { err, handle, isBlocked, supabase, verifyFirebaseToken } from '../_shared/backend.ts'

Deno.serve((req: Request) => handle(req, async (req) => {
  const header = req.headers.get('Authorization') ?? ''
  if (!header.startsWith('Bearer ')) throw err('unauthenticated', 'Sign in required')
  let identity
  try { identity = await verifyFirebaseToken(header.slice(7).trim()) }
  catch { throw err('unauthenticated', 'Sign in required') }
  if (!identity.email_verified || !identity.email) {
    throw err('failed-precondition', 'Verify your email before updating it')
  }
  if (await isBlocked(identity.uid)) throw err('permission-denied', 'Account blocked')
  // Identity and email come exclusively from a verified Firebase token, never the body.
  const { data, error } = await supabase.from('users')
    .update({ email: identity.email, is_verified: true })
    .eq('user_id', identity.uid).select('email').single()
  if (error) throw err('failed-precondition', 'Could not synchronize your verified email. Please try again.')
  return { email: data.email }
}))
