/**
 * Pure payment helpers (Supabase Edge Functions).
 *
 * Ported from functions/src/payments.ts — the webhook signature check now uses
 * Web Crypto (Deno/Node 20+ both ship `globalThis.crypto`), compared in
 * constant time without Node's `crypto.timingSafeEqual`. PURE module: no
 * imports, jest-testable.
 */

function toBytes(s: string): Uint8Array {
  const b = new Uint8Array(s.length)
  for (let i = 0; i < s.length; i++) b[i] = s.charCodeAt(i)
  return b
}

function bytesToHex(bytes: Uint8Array): string {
  let hex = ''
  for (const byte of bytes) hex += byte.toString(16).padStart(2, '0')
  return hex
}

function constantTimeEq(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i]
  return diff === 0
}

function subtle(): any {
  const c = (globalThis as any).crypto
  if (!c?.subtle) throw new Error('Web Crypto not available')
  return c.subtle
}

/**
 * Verifies the `Paymongo-Signature` header against the RAW request body.
 * HMAC-SHA256 of the body with the endpoint webhook secret, compared in
 * constant time. MUST run before parsing the body or touching the database.
 */
export async function verifyWebhookSignature(
  rawBody: Uint8Array | string,
  secret: string,
  signatureHeader: string,
): Promise<boolean> {
  const body = typeof rawBody === 'string' ? toBytes(rawBody) : rawBody
  const key = await subtle().importKey(
    'raw',
    toBytes(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const mac = new Uint8Array(await subtle().sign('HMAC', key, body))
  return constantTimeEq(toBytes(bytesToHex(mac)), toBytes(signatureHeader))
}

export type PayMongoMethod = 'card' | 'gcash' | 'maya'

/**
 * App payment-method ids → PayMongo source names. The app's id is `paymaya`
 * today; PayMongo's current source is `maya` — map, don't pass through.
 */
const METHOD_ALIASES: Record<string, PayMongoMethod> = {
  card: 'card',
  gcash: 'gcash',
  maya: 'maya',
  paymaya: 'maya',
}

export function normalizePaymentMethod(method: unknown): PayMongoMethod | null {
  if (typeof method !== 'string') {
    return null
  }
  return METHOD_ALIASES[method.toLowerCase()] ?? null
}

/**
 * Server-side order total in centavos — NEVER trust the client's amount.
 * Mirrors the revenue math in the sales rollup so every surface agrees.
 */
export function computeOrderAmountCents(order: Record<string, unknown>): number {
  const itemsTotal = Array.isArray(order.items)
    ? (order.items as Array<{ unitPrice?: number; quantity?: number }>).reduce(
        (sum, i) => sum + (i.unitPrice ?? 0) * (i.quantity ?? 0),
        0,
      )
    : 0
  const total =
    itemsTotal +
    (typeof order.deliveryFee === 'number' ? order.deliveryFee : 0) +
    (typeof order.serviceFee === 'number' ? order.serviceFee : 0) +
    (typeof order.priorityFee === 'number' ? order.priorityFee : 0)
  return Math.round(total * 100)
}
