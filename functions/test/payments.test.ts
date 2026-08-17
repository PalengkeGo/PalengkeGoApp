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
  computeOrderAmountCents,
  normalizePaymentMethod,
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

  it('accepts a valid signature', () => {
    expect(verifyWebhookSignature(body, SECRET, sign(body, SECRET))).toBe(true);
  });

  it('rejects a tampered body', () => {
    const tampered = body.replace('paid', 'failed');
    expect(verifyWebhookSignature(tampered, SECRET, sign(body, SECRET))).toBe(
      false,
    );
  });

  it('rejects a signature from a different secret', () => {
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
