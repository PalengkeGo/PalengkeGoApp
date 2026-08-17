/**
 * Unit tests for the shared rate-limiter decision logic (no emulator needed).
 *
 * src/security.ts calls admin.firestore() at module scope, so the default app
 * must exist before the module loads. Imports hoist, so use require here.
 */
import * as admin from 'firebase-admin';

admin.initializeApp({ projectId: 'demo-palengkego' });
const { rateLimitDecision } = require('../src/security');

const WINDOW = 60 * 1000;
const NOW = 1_000_000;

describe('rateLimitDecision', () => {
  it('starts a fresh window for a new key', () => {
    expect(rateLimitDecision(undefined, undefined, NOW, 10)).toEqual({
      allowed: true,
      windowStart: NOW,
      count: 1,
    });
  });

  it('allows up to the per-minute cap', () => {
    const d1 = rateLimitDecision(NOW, 1, NOW, 10);
    expect(d1).toEqual({ allowed: true, windowStart: NOW, count: 2 });
    const d2 = rateLimitDecision(NOW, 9, NOW, 10);
    expect(d2.allowed).toBe(true);
    expect(d2.count).toBe(10);
  });

  it('rejects once the cap is reached within the window', () => {
    const d = rateLimitDecision(NOW, 10, NOW, 10);
    expect(d.allowed).toBe(false);
  });

  it('resets after the window elapses', () => {
    const d = rateLimitDecision(NOW, 10, NOW + WINDOW, 10);
    expect(d).toEqual({ allowed: true, windowStart: NOW + WINDOW, count: 1 });
  });

  it('treats a corrupted counter as a fresh window', () => {
    const d = rateLimitDecision(undefined, 99, NOW, 5);
    expect(d.allowed).toBe(true);
    expect(d.count).toBe(1);
  });
});
