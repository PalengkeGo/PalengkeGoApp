/**
 * Cross-check: the Supabase Edge Function ports of the trusted helpers
 * (supabase/functions/_shared/*) must behave identically to the Cloud
 * Functions versions (src/*). Pure modules — no firebase import, no emulator.
 *
 * Run: npx jest edge_shared.test.ts
 */
import { createHmac } from 'crypto'
import {
  computeFees,
  FEE_CONFIG,
  canTransition,
  TERMINAL_STATUSES,
  isCashPayment,
  validateOptionalText,
  FIELD_LIMITS,
} from '../../supabase/functions/_shared/constants'
import { rateLimitDecision } from '../../supabase/functions/_shared/security'
import {
  computeOrderAmountCents,
  normalizePaymentMethod,
  parseSignatureHeader,
  verifyWebhookSignature,
} from '../../supabase/functions/_shared/logic'

const WINDOW = 60 * 1000
const NOW = 1_000_000

// Hardcoded vector so the port can't fake agreement with itself:
// HMAC-SHA256('webhook-secret', '{"id":"evt_1"}').
const HMAC_VECTOR = 'ae7fe5a23f510c995581ac90745030443d6b69b86231107f4fecfc6f47271332'

describe('edge _shared/constants (port of src/constants)', () => {
  it('mirrors the Flutter FeeConfig values', () => {
    expect(FEE_CONFIG.deliveryFee).toBe(49.0)
    expect(FEE_CONFIG.serviceFee).toBe(15.0)
    expect(FEE_CONFIG.priorityFee).toBe(29.0)
    expect(computeFees('delivery', true)).toEqual({
      deliveryFee: 49.0,
      serviceFee: 15.0,
      priorityFee: 29.0,
    })
    expect(computeFees('pickup', true)).toEqual({
      deliveryFee: 0,
      serviceFee: 15.0,
      priorityFee: 0,
    })
  })

  it('allows the vendor workflow and the customer cancel only', () => {
    expect(canTransition('pending', 'confirmed')).toBe(true)
    expect(canTransition('confirmed', 'preparing')).toBe(true)
    expect(canTransition('preparing', 'ready')).toBe(true)
    expect(canTransition('ready', 'completed')).toBe(true)
    expect(canTransition('pending', 'cancelled')).toBe(true)
    expect(canTransition('pending', 'completed')).toBe(false)
    expect(canTransition('completed', 'cancelled')).toBe(false)
    for (const s of ['completed', 'cancelled', 'rejected']) {
      expect(TERMINAL_STATUSES.has(s as never)).toBe(true)
    }
  })

  it('treats cod/cop as cash, online methods as not', () => {
    expect(isCashPayment('cod')).toBe(true)
    expect(isCashPayment('cop')).toBe(true)
    expect(isCashPayment('gcash')).toBe(false)
    expect(isCashPayment(undefined)).toBe(false)
  })

  it('validates optional text fields', () => {
    expect(validateOptionalText(undefined, 100, 'x')).toBeNull()
    expect(validateOptionalText('ok', 100, 'x')).toBeNull()
    expect(validateOptionalText('a'.repeat(501), FIELD_LIMITS.notes, 'notes')).toContain('500')
  })
})

describe('edge _shared/security (port of src/security)', () => {
  it('starts a fresh window for a new key', () => {
    expect(rateLimitDecision(undefined, undefined, NOW, 10)).toEqual({
      allowed: true,
      windowStart: NOW,
      count: 1,
    })
  })

  it('allows up to the cap, then rejects within the window', () => {
    expect(rateLimitDecision(NOW, 1, NOW, 10)).toEqual({
      allowed: true,
      windowStart: NOW,
      count: 2,
    })
    expect(rateLimitDecision(NOW, 10, NOW, 10).allowed).toBe(false)
    expect(rateLimitDecision(NOW, 10, NOW + WINDOW, 10)).toEqual({
      allowed: true,
      windowStart: NOW + WINDOW,
      count: 1,
    })
  })
})

describe('edge _shared/logic (port of src/payments.ts pure helpers)', () => {
  it('verifies a known HMAC-SHA256 vector', async () => {
    expect(await verifyWebhookSignature('{"id":"evt_1"}', 'webhook-secret', HMAC_VECTOR)).toBe(true)
  })

  it('rejects a tampered body, a different secret, and garbage headers', async () => {
    expect(await verifyWebhookSignature('{"id":"evt_2"}', 'webhook-secret', HMAC_VECTOR)).toBe(false)
    expect(await verifyWebhookSignature('{"id":"evt_1"}', 'other-secret', HMAC_VECTOR)).toBe(false)
    expect(await verifyWebhookSignature('{"id":"evt_1"}', 'webhook-secret', 'deadbeef')).toBe(false)
    expect(await verifyWebhookSignature('{"id":"evt_1"}', 'webhook-secret', '')).toBe(false)
  })

  it('accepts a Uint8Array body identical to the string form', async () => {
    const body = new TextEncoder().encode('{"id":"evt_1"}')
    expect(await verifyWebhookSignature(body, 'webhook-secret', HMAC_VECTOR)).toBe(true)
  })

  it('verifies segmented (t/te/li) headers exactly like src/payments.ts', async () => {
    const body = '{"id":"evt_1"}'
    const nowMs = 1_755_000_000_000
    const ts = Math.floor(nowMs / 1000)
    const te = createHmac('sha256', 'webhook-secret').update(`${ts}.${body}`).digest('hex')
    const li = createHmac('sha256', 'live-secret').update(`${ts}.${body}`).digest('hex')

    // Test-mode segment present.
    expect(await verifyWebhookSignature(body, 'webhook-secret', `t=${ts},te=${te},li=`, nowMs)).toBe(true)
    // Live-mode segment present (configured secret must match that segment).
    expect(await verifyWebhookSignature(body, 'live-secret', `t=${ts},te=,li=${li}`, nowMs)).toBe(true)
    // Tampered body / wrong secret / stale timestamp / missing t all fail.
    expect(await verifyWebhookSignature('{"id":"evt_2"}', 'webhook-secret', `t=${ts},te=${te},li=`, nowMs)).toBe(false)
    expect(await verifyWebhookSignature(body, 'other-secret', `t=${ts},te=${te},li=`, nowMs)).toBe(false)
    const stale = Math.floor(nowMs / 1000) - 6 * 60
    const staleSig = createHmac('sha256', 'webhook-secret').update(`${stale}.${body}`).digest('hex')
    expect(await verifyWebhookSignature(body, 'webhook-secret', `t=${stale},te=${staleSig},li=`, nowMs)).toBe(false)
    expect(await verifyWebhookSignature(body, 'webhook-secret', `te=${te}`, nowMs)).toBe(false)
  })

  it('parses t/te/li segments', () => {
    expect(parseSignatureHeader('t=1496734173,te=abc,li=')).toEqual({
      t: '1496734173',
      te: 'abc',
      li: '',
    })
    expect(parseSignatureHeader('deadbeef')).toEqual({})
  })

  it('maps app payment ids to PayMongo sources', () => {
    expect(normalizePaymentMethod('paymaya')).toBe('maya') // legacy id
    expect(normalizePaymentMethod('PayMaya')).toBe('maya')
    expect(normalizePaymentMethod('gcash')).toBe('gcash')
    expect(normalizePaymentMethod('card')).toBe('card')
    expect(normalizePaymentMethod('banco')).toBeNull()
    expect(normalizePaymentMethod(42)).toBeNull()
  })

  it('sums items and fees, converting to centavos', () => {
    const order = {
      items: [
        { unitPrice: 150, quantity: 2 },
        { unitPrice: 49.5, quantity: 1 },
      ],
      deliveryFee: 49,
      serviceFee: 15,
      priorityFee: 29,
    }
    expect(computeOrderAmountCents(order)).toBe(
      Math.round((150 * 2 + 49.5 + 49 + 15 + 29) * 100),
    )
    expect(computeOrderAmountCents({ items: [{ unitPrice: 100, quantity: 1 }] })).toBe(10000)
    expect(computeOrderAmountCents({})).toBe(0)
  })
})
