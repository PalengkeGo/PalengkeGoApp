/**
 * Unit tests for the payment layer's pure helpers.
 *
 * Runs under plain jest (`npm test` / `npx jest payments.test.ts`) — no
 * emulator needed. The webhook/callable integration is exercised against the
 * Firestore emulator via the full `test:rules` suite.
 */
import { createHmac } from 'crypto';
import * as admin from 'firebase-admin';

// src/payments.ts calls admin.firestore() at module scope, so the default app
// must exist before the module loads. Imports hoist, so use require here.
admin.initializeApp({ projectId: 'demo-palengkego' });
const {
  claimDecision,
  computeOrderAmountCents,
  normalizePaymentMethod,
  parseSignatureHeader,
  verifyWebhookSignature,
} = require('../src/payments');

const SECRET = 'whsec_test_0123456789abcdef';

function sign(raw: string, secret: string): string {
  return createHmac('sha256', secret).update(raw).digest('hex');
}

describe('verifyWebhookSignature', () => {
  const body = JSON.stringify({
    data: { attributes: { type: 'payment.paid' } },
  });

  // PayMongo's documented segmented header: t=<unix seconds>,te=<test sig>,li=<live sig>.
  // The signed string is `<t>.<raw body>`.
  function signSegmented(raw: string, secret: string, tsSeconds: number): string {
    const sig = createHmac('sha256', secret).update(`${tsSeconds}.${raw}`).digest('hex');
    return `t=${tsSeconds},te=${sig},li=`;
  }

  const NOW_MS = 1_755_000_000_000;

  it('accepts a valid legacy bare-hex signature', () => {
    expect(verifyWebhookSignature(body, SECRET, sign(body, SECRET))).toBe(true);
  });

  it('accepts a valid segmented test-mode signature', () => {
    const ts = Math.floor(NOW_MS / 1000);
    expect(
      verifyWebhookSignature(body, SECRET, signSegmented(body, SECRET, ts), NOW_MS),
    ).toBe(true);
  });

  it('accepts a valid segmented live-mode signature', () => {
    const ts = Math.floor(NOW_MS / 1000);
    const sig = createHmac('sha256', SECRET).update(`${ts}.${body}`).digest('hex');
    expect(
      verifyWebhookSignature(body, SECRET, `t=${ts},te=,li=${sig}`, NOW_MS),
    ).toBe(true);
  });

  it('rejects a segmented signature over a tampered body', () => {
    const ts = Math.floor(NOW_MS / 1000);
    const tampered = body.replace('paid', 'failed');
    expect(
      verifyWebhookSignature(tampered, SECRET, signSegmented(body, SECRET, ts), NOW_MS),
    ).toBe(false);
  });

  it('rejects a segmented signature from a different secret', () => {
    const ts = Math.floor(NOW_MS / 1000);
    expect(
      verifyWebhookSignature(
        body,
        SECRET,
        signSegmented(body, 'other-secret', ts),
        NOW_MS,
      ),
    ).toBe(false);
  });

  it('rejects a stale segmented signature outside the replay window', () => {
    const staleTs = Math.floor(NOW_MS / 1000) - 6 * 60; // 6 min old
    expect(
      verifyWebhookSignature(body, SECRET, signSegmented(body, SECRET, staleTs), NOW_MS),
    ).toBe(false);
  });

  it('rejects a segmented header without a timestamp segment', () => {
    const ts = Math.floor(NOW_MS / 1000);
    const sig = createHmac('sha256', SECRET).update(`${ts}.${body}`).digest('hex');
    expect(verifyWebhookSignature(body, SECRET, `te=${sig}`, NOW_MS)).toBe(false);
  });

  it('rejects a malformed timestamp (fails closed, no NaN window math)', () => {
    expect(
      verifyWebhookSignature(body, SECRET, `t=notanumber,te=${sign(body, SECRET)},li=`, NOW_MS),
    ).toBe(false);
  });

  it('rejects a tampered body (legacy format)', () => {
    const tampered = body.replace('paid', 'failed');
    expect(verifyWebhookSignature(tampered, SECRET, sign(body, SECRET))).toBe(
      false,
    );
  });

  it('rejects a signature from a different secret (legacy format)', () => {
    expect(verifyWebhookSignature(body, SECRET, sign(body, 'other-secret'))).toBe(
      false,
    );
  });

  it('rejects a mismatched-length header', () => {
    expect(verifyWebhookSignature(body, SECRET, 'deadbeef')).toBe(false);
  });

  it('rejects an empty header', () => {
    expect(verifyWebhookSignature(body, SECRET, '')).toBe(false);
  });
});

describe('parseSignatureHeader', () => {
  it('extracts t, te, li segments', () => {
    expect(
      parseSignatureHeader('t=1496734173,te=abc123,li='),
    ).toEqual({ t: '1496734173', te: 'abc123', li: '' });
  });

  it('returns undefined segments for a bare hex header', () => {
    expect(parseSignatureHeader('deadbeef')).toEqual({});
  });
});

describe('claimDecision (stale processing recovery)', () => {
  const NOW = 1_755_000_000_000;
  const STALE = 10 * 60 * 1000;

  it('rejects a fresh processing claim', () => {
    expect(claimDecision('int_1', NOW - STALE / 2, NOW)).toBe('fresh-processing');
    expect(claimDecision(undefined, NOW - 1000, NOW)).toBe('fresh-processing');
  });

  it('reclaims a stale claim with no stamped intent (crash between claim and stamp)', () => {
    expect(claimDecision(undefined, NOW - STALE - 1, NOW)).toBe('reclaim');
    expect(claimDecision(null, undefined, NOW)).toBe('reclaim');
  });

  it('requires intent inspection when a stale claim has a stamped intent', () => {
    expect(claimDecision('int_1', NOW - STALE - 1, NOW)).toBe('inspect-intent');
  });

  it('treats a missing updatedAt as stale (never permanently locks an order)', () => {
    expect(claimDecision('int_1', undefined, NOW)).toBe('inspect-intent');
    expect(claimDecision(undefined, undefined, NOW)).toBe('reclaim');
  });
});

describe('normalizePaymentMethod', () => {
  it('maps app payment ids to PayMongo sources', () => {
    expect(normalizePaymentMethod('gcash')).toBe('gcash');
    expect(normalizePaymentMethod('paymaya')).toBe('maya'); // legacy id
    expect(normalizePaymentMethod('maya')).toBe('maya');
    expect(normalizePaymentMethod('card')).toBe('card');
  });

  it('is case-insensitive', () => {
    expect(normalizePaymentMethod('PayMaya')).toBe('maya');
  });

  it('rejects unknown or non-string methods', () => {
    expect(normalizePaymentMethod('banco')).toBeNull();
    expect(normalizePaymentMethod(42)).toBeNull();
    expect(normalizePaymentMethod(undefined)).toBeNull();
  });
});

describe('computeOrderAmountCents', () => {
  it('sums items and fees, converting to centavos', () => {
    const order = {
      items: [
        { unitPrice: 150, quantity: 2 },
        { unitPrice: 49.5, quantity: 1 },
      ],
      deliveryFee: 49,
      serviceFee: 15,
      priorityFee: 29,
    };
    expect(computeOrderAmountCents(order)).toBe(
      Math.round((150 * 2 + 49.5 + 49 + 15 + 29) * 100),
    );
  });

  it('handles missing fees', () => {
    const order = { items: [{ unitPrice: 100, quantity: 1 }] };
    expect(computeOrderAmountCents(order)).toBe(10000);
  });

  it('returns 0 for an empty order', () => {
    expect(computeOrderAmountCents({})).toBe(0);
  });
});
