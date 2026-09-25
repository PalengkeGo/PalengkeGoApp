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

import { createRemoteJWKSet, jwtVerify } from 'npm:jose@^5.9.6'

const JWKS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'),
)

function getProjectId(): string {
  try {
    const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (raw) {
      const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw
      if (parsed.project_id) return parsed.project_id
    }
  } catch (_) {}
  return 'palengkegodb'
}

export async function verifyFirebaseToken(token: string): Promise<{ uid: string; email_verified?: boolean }> {
  const projectId = getProjectId()
  const { payload } = await jwtVerify(token, JWKS, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
  })
  const uid = (payload.user_id as string) || (payload.sub as string)
  if (!uid) {
    throw new Error('Token does not contain a valid user ID')
  }
  return {
    uid,
    email_verified: payload.email_verified === true,
  }
}

import { ApiError, err, HTTP_STATUS } from './errors.ts'
// Re-exported so every edge function can import everything from backend.ts.
export { ApiError, err, HTTP_STATUS } from './errors.ts'

export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-upload-token',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
}

/** Serializes fn's result as JSON; maps ApiError → status + {error:{code,message}}. */
export async function handle(
  req: Request,
  fn: (req: Request) => Promise<unknown>,
): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  try {
    const result = await fn(req)
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    if (e instanceof ApiError) {
      return new Response(
        JSON.stringify({ error: { code: e.code, message: e.message } }),
        { status: HTTP_STATUS[e.code] ?? 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }
    console.error(e)
    return new Response(
      JSON.stringify({ error: { code: 'internal', message: 'Internal error' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
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
    const verified = await verifyFirebaseToken(token)
    // Server-side email-verification gate (customers registering by
    // email/password must verify before ordering; Google sign-in accounts
    // always carry email_verified = true, so they pass naturally).
    if (requireEmailVerified && !verified.email_verified) {
      throw err('failed-precondition', 'Verify your email before placing orders')
    }
    return verified.uid
  } catch (e) {
    if (e instanceof ApiError) throw e
    console.error('verifyFirebaseToken failed:', e)
    throw err('unauthenticated', `Sign in required: ${e instanceof Error ? e.message : String(e)}`)
  }
}

import { createClient } from 'npm:@supabase/supabase-js'
const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
export const supabase = createClient(supabaseUrl, supabaseKey)

export async function roleOf(uid: string): Promise<string | null> {
  const { data } = await supabase
    .from('users')
    .select('role')
    .eq('user_id', uid)
    .single();
  return data?.role as string | null;
}

/** True when the user doc explicitly marks the account blocked. */
export async function isBlocked(uid: string): Promise<boolean> {
  const { data } = await supabase
    .from('users')
    .select('is_blocked')
    .eq('user_id', uid)
    .single();
  return data?.is_blocked === true;
}

export async function stallOwnerUid(stallId: string): Promise<string | null> {
  const { data } = await supabase
    .from('stall_holders')
    .select('user_id')
    .eq('stall_holder_id', stallId)
    .single();
  return data?.user_id as string | null;
}

export function assertRole(role: string | null, expected: string[]): void {
  if (!role || !expected.includes(role)) {
    throw err('permission-denied', 'You do not have permission for this operation')
  }
}
