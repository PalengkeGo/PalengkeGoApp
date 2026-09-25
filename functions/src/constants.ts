/**
 * Shared domain constants for the trusted backend.
 *
 * These mirror the Flutter-side enums (OrderStatus, PaymentStatus,
 * FeeConfig.cancelWindow = 5 min) so both sides agree on the same graph.
 */

export const CANCELLATION_WINDOW_MS = 5 * 60 * 1000; // mirrors FeeConfig.cancelWindow

// Overridable so the emulator-based E2E suite can point the functions at a
// stub PayMongo; production uses the real API.
export const PAYMONGO_API_URL =
  process.env.PAYMONGO_API_URL || 'https://api.paymongo.com/v1';

/**
 * Payment method ids the app can select (mirrors the payment methods screen
 * and CustomerPreferences). `cop` = cash on pickup.
 */
export const PAYMENT_METHODS = ['cod', 'cop', 'gcash', 'paymaya', 'card'] as const;
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];

/**
 * Cash methods are settled at delivery/pickup, so the vendor completing the
 * order legitimately marks them paid. Online methods (gcash/paymaya/card) are
 * only ever marked paid by the verified PayMongo webhook.
 */
export function isCashPayment(method: unknown): boolean {
  return method === 'cod' || method === 'cop';
}

/**
 * Text-field limits enforced server-side (mirrors the Firestore rules) to
 * prevent storage abuse from unbounded client strings.
 */
export const FIELD_LIMITS = {
  customerName: 100,
  deliveryAddress: 200,
  notes: 500,
  remarks: 300,
  reviewComment: 500,
  reviewProductName: 100,
  refundReason: 200,
} as const;

function withinLimit(value: unknown, max: number): boolean {
  return typeof value === 'string' && value.length <= max;
}

/**
 * Returns null when the optional string field is absent or within its limit,
 * otherwise an error message. Use for optional free-text inputs.
 */
export function validateOptionalText(
  value: unknown,
  max: number,
  field: string,
): string | null {
  if (value === undefined || value === null) return null;
  return withinLimit(value, max) ? null : `${field} is too long (max ${max})`;
}

/**
 * Mirrors Flutter's FeeConfig (lib/core/config/fee_config.dart) so the trusted
 * backend computes the SAME fees the UI shows. The client may not dictate
 * prices — fees are derived server-side from fulfillment + priority flags.
 */
export const FEE_CONFIG = {
  serviceFee: 0.0, // FeeConfig.serviceFee
  priorityFee: 29.0, // FeeConfig.priorityFee
  // Distance-based delivery: ₱30 base + ₱10/km from Naga City People's Mall
  deliveryBaseCharge: 30.0,
  deliveryPerKm: 10.0,
  // Origin: Naga City People's Mall (reference point for distance calc)
  deliveryOriginLat: 13.5864,
  deliveryOriginLng: 121.1848,
} as const;

export interface OrderFees {
  deliveryFee: number;
  serviceFee: number;
  priorityFee: number;
  deliveryDistanceKm?: number;
}

/**
 * Haversine formula: great-circle distance (km) between two lat/lng points.
 * Accurate for real-world delivery distances (<50km).
 */
function haversineDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6371; // Earth radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Server-side fee computation. Pickup has no delivery or priority fee.
 * Delivery fee is distance-based: ₱30 base + ₱10/km from mall origin.
 * If delivery lat/lng are missing or invalid, uses flat base charge.
 */
export function computeFees(
  fulfillmentMethod: string,
  isPriority: boolean,
  deliveryLatitude?: number | null,
  deliveryLongitude?: number | null,
): OrderFees {
  const isPickup = fulfillmentMethod === 'pickup';
  
  let deliveryFee = 0;
  let deliveryDistanceKm: number | undefined = undefined;

  if (!isPickup) {
    // Calculate distance-based fee if valid coordinates provided
    if (
      typeof deliveryLatitude === 'number' &&
      typeof deliveryLongitude === 'number' &&
      Number.isFinite(deliveryLatitude) &&
      Number.isFinite(deliveryLongitude)
    ) {
      deliveryDistanceKm = haversineDistance(
        FEE_CONFIG.deliveryOriginLat,
        FEE_CONFIG.deliveryOriginLng,
        deliveryLatitude,
        deliveryLongitude,
      );
      // ₱30 base + ₱10/km
      deliveryFee = FEE_CONFIG.deliveryBaseCharge + deliveryDistanceKm * FEE_CONFIG.deliveryPerKm;
    } else {
      // Fallback: use base charge if no coordinates
      deliveryFee = FEE_CONFIG.deliveryBaseCharge;
    }
  }

  return {
    deliveryFee,
    serviceFee: FEE_CONFIG.serviceFee,
    priorityFee: isPickup ? 0 : isPriority ? FEE_CONFIG.priorityFee : 0,
    deliveryDistanceKm,
  };
}

export type OrderStatus =
  | 'pending'
  | 'confirmed'
  | 'preparing'
  | 'ready'
  | 'completed'
  | 'cancelled'
  | 'rejected';

export const TERMINAL_STATUSES: ReadonlySet<OrderStatus> = new Set([
  'completed',
  'cancelled',
  'rejected',
]);

const TRANSITIONS: Record<OrderStatus, ReadonlySet<OrderStatus>> = {
  pending: new Set(['confirmed', 'preparing', 'rejected', 'cancelled']),
  confirmed: new Set(['preparing', 'cancelled']),
  preparing: new Set(['ready', 'cancelled']),
  ready: new Set(['completed']),
  completed: new Set(),
  cancelled: new Set(),
  rejected: new Set(),
};

export function canTransition(
  from: OrderStatus,
  to: OrderStatus,
): boolean {
  return TRANSITIONS[from].has(to);
}

export interface OrderItemInput {
  productId: string;
  quantity: number;
  unit?: string;
}