/**
 * Unit tests for order-domain pure helpers (constants.ts) — no emulator.
 */
import {
  computeFees,
  FEE_CONFIG,
  canTransition,
  TERMINAL_STATUSES,
  isCashPayment,
  validateOptionalText,
  FIELD_LIMITS,
} from '../src/constants';

describe('computeFees', () => {
  it('uses base delivery charge when no coordinates provided', () => {
    expect(computeFees('delivery', false)).toEqual({
      deliveryFee: FEE_CONFIG.deliveryBaseCharge,
      serviceFee: FEE_CONFIG.serviceFee,
      priorityFee: 0,
      deliveryDistanceKm: undefined,
    });
  });

  it('calculates distance-based fee with valid coordinates', () => {
    // Coordinates near the mall origin (~1 km away)
    const result = computeFees('delivery', false, 13.5975, 121.1848);
    expect(result.serviceFee).toBe(FEE_CONFIG.serviceFee);
    expect(result.priorityFee).toBe(0);
    expect(result.deliveryDistanceKm).toBeDefined();
    expect(result.deliveryDistanceKm).toBeGreaterThan(0);
    // Fee should be base + (distance * per-km rate)
    expect(result.deliveryFee).toBe(
      FEE_CONFIG.deliveryBaseCharge + result.deliveryDistanceKm! * FEE_CONFIG.deliveryPerKm
    );
  });

  it('adds the priority fee only for priority delivery', () => {
    expect(computeFees('delivery', true)).toEqual({
      deliveryFee: FEE_CONFIG.deliveryBaseCharge,
      serviceFee: FEE_CONFIG.serviceFee,
      priorityFee: FEE_CONFIG.priorityFee,
      deliveryDistanceKm: undefined,
    });
  });

  it('waives delivery and priority fees for pickup', () => {
    expect(computeFees('pickup', true)).toEqual({
      deliveryFee: 0,
      serviceFee: FEE_CONFIG.serviceFee,
      priorityFee: 0,
      deliveryDistanceKm: undefined,
    });
  });

  it('mirrors the Flutter FeeConfig values', () => {
    expect(FEE_CONFIG.serviceFee).toBe(15.0);
    expect(FEE_CONFIG.priorityFee).toBe(29.0);
    expect(FEE_CONFIG.deliveryBaseCharge).toBe(30.0);
    expect(FEE_CONFIG.deliveryPerKm).toBe(10.0);
  });

  it('ignores invalid coordinates (NaN, Infinity, non-numbers)', () => {
    expect(computeFees('delivery', false, NaN, 121.1848)).toEqual({
      deliveryFee: FEE_CONFIG.deliveryBaseCharge,
      serviceFee: FEE_CONFIG.serviceFee,
      priorityFee: 0,
      deliveryDistanceKm: undefined,
    });
    expect(computeFees('delivery', false, 13.5864, Infinity)).toEqual({
      deliveryFee: FEE_CONFIG.deliveryBaseCharge,
      serviceFee: FEE_CONFIG.serviceFee,
      priorityFee: 0,
      deliveryDistanceKm: undefined,
    });
    expect(computeFees('delivery', false, null, 121.1848)).toEqual({
      deliveryFee: FEE_CONFIG.deliveryBaseCharge,
      serviceFee: FEE_CONFIG.serviceFee,
      priorityFee: 0,
      deliveryDistanceKm: undefined,
    });
  });
});

describe('isCashPayment', () => {
  it('treats cod and cop as cash', () => {
    expect(isCashPayment('cod')).toBe(true);
    expect(isCashPayment('cop')).toBe(true);
  });

  it('treats online methods as non-cash', () => {
    expect(isCashPayment('gcash')).toBe(false);
    expect(isCashPayment('paymaya')).toBe(false);
    expect(isCashPayment('card')).toBe(false);
    expect(isCashPayment(undefined)).toBe(false);
    expect(isCashPayment(42)).toBe(false);
  });
});

describe('validateOptionalText', () => {
  it('accepts absent and within-limit strings', () => {
    expect(validateOptionalText(undefined, 100, 'x')).toBeNull();
    expect(validateOptionalText(null, 100, 'x')).toBeNull();
    expect(validateOptionalText('ok', 100, 'x')).toBeNull();
  });

  it('rejects over-limit strings with a field-specific message', () => {
    const err = validateOptionalText('a'.repeat(501), FIELD_LIMITS.notes, 'notes');
    expect(err).toContain('notes');
    expect(err).toContain('500');
  });
});

describe('order status graph', () => {
  it('allows the vendor workflow and the customer cancel', () => {
    expect(canTransition('pending', 'confirmed')).toBe(true);
    expect(canTransition('confirmed', 'preparing')).toBe(true);
    expect(canTransition('preparing', 'ready')).toBe(true);
    expect(canTransition('ready', 'completed')).toBe(true);
    expect(canTransition('pending', 'cancelled')).toBe(true);
  });

  it('rejects illegal and terminal transitions', () => {
    expect(canTransition('pending', 'completed')).toBe(false);
    expect(canTransition('completed', 'cancelled')).toBe(false);
    expect(canTransition('cancelled', 'pending')).toBe(false);
  });

  it('treats completed/cancelled/rejected as terminal', () => {
    for (const s of ['completed', 'cancelled', 'rejected']) {
      expect(TERMINAL_STATUSES.has(s as never)).toBe(true);
    }
  });
});
