/**
 * Shared domain constants for the trusted backend (Supabase Edge Functions).
 *
 * Ported from functions/src/constants.ts — mirrors the Flutter-side enums
 * (OrderStatus, PaymentStatus, FeeConfig.cancelWindow = 5 min) so both sides
 * agree on the same graph. PURE module: no imports, jest-testable.
 */

export const CANCELLATION_WINDOW_MS = 5 * 60 * 1000 // mirrors FeeConfig.cancelWindow

export const PAYMONGO_API_URL = 'https://api.paymongo.com/v1'

/**
 * Payment method ids the app can select (mirrors the payment methods screen
 * and CustomerPreferences). `cop` = cash on pickup.
 */
export const PAYMENT_METHODS = ['cod', 'cop', 'gcash', 'paymaya', 'card'] as const
export type PaymentMethod = (typeof PAYMENT_METHODS)[number]

/**
 * Cash methods are settled at delivery/pickup, so the vendor completing the
 * order legitimately marks them paid. Online methods (gcash/paymaya/card) are
 * only ever marked paid by the verified PayMongo webhook.
 */
export function isCashPayment(method: unknown): boolean {
  return method === 'cod' || method === 'cop'
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
} as const

function withinLimit(value: unknown, max: number): boolean {
  return typeof value === 'string' && value.length <= max
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
  if (value === undefined || value === null) return null
  return withinLimit(value, max) ? null : `${field} is too long (max ${max})`
}

/**
 * Mirrors Flutter's FeeConfig (lib/core/config/fee_config.dart) so the trusted
 * backend computes the SAME fees the UI shows. The client may not dictate
 * prices — fees are derived server-side from fulfillment + priority flags and
 * (for delivery) the distance from the delivery origin.
 */
export const FEE_CONFIG = {
  deliveryFee: 49.0, // FeeConfig.deliveryFee — flat fallback when no pin
  serviceFee: 15.0, // FeeConfig.serviceFee
  priorityFee: 29.0, // FeeConfig.priorityFee
  // FeeConfig.deliveryBaseRate / deliveryRatePerKm:
  //   deliveryFee = deliveryBaseRate + deliveryRatePerKm × distanceKm
  deliveryBaseRate: 30.0,
  deliveryRatePerKm: 10.0,
} as const

/**
 * Delivery origin for distance-based fees: Naga City People's Mall
 * (mirrors LocationDistanceService.nagaPeoplesMallLat/Lng).
 */
export const DELIVERY_ORIGIN = {
  lat: 13.6218,
  lng: 123.1948,
} as const

/**
 * Haversine great-circle distance in km (mirrors
 * LocationDistanceService.haversineKm, Earth radius 6371 km).
 */
export function calculateHaversineDistanceKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const r = 6371.0
  const toRad = (d: number) => d * (Math.PI / 180)
  const dLat = toRad(lat2 - lat1)
  const dLon = toRad(lon2 - lon1)
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return r * c
}

export interface OrderFees {
  deliveryFee: number
  serviceFee: number
  priorityFee: number
  /** Straight-line distance origin → destination in km, when coordinates were provided. */
  deliveryDistanceKm?: number
}

/**
 * Server-side fee computation. Pickup has no delivery or priority fee. Delivery
 * orders with a finite destination pin are priced by distance from
 * [DELIVERY_ORIGIN]; missing/invalid coordinates keep the flat
 * [FEE_CONFIG.deliveryFee] fallback.
 */
export function computeFees(
  fulfillmentMethod: string,
  isPriority: boolean,
  deliveryLatitude?: unknown,
  deliveryLongitude?: unknown,
): OrderFees {
  const isPickup = fulfillmentMethod === 'pickup'
  const lat = typeof deliveryLatitude === 'number' ? deliveryLatitude : NaN
  const lon = typeof deliveryLongitude === 'number' ? deliveryLongitude : NaN
  const hasPin = Number.isFinite(lat) && Number.isFinite(lon)

  let deliveryFee = isPickup ? 0 : FEE_CONFIG.deliveryFee
  let deliveryDistanceKm: number | undefined
  if (!isPickup && hasPin) {
    deliveryDistanceKm = calculateHaversineDistanceKm(
      DELIVERY_ORIGIN.lat,
      DELIVERY_ORIGIN.lng,
      lat,
      lon,
    )
    deliveryFee =
      FEE_CONFIG.deliveryBaseRate + FEE_CONFIG.deliveryRatePerKm * deliveryDistanceKm
  }

  return {
    deliveryFee,
    serviceFee: FEE_CONFIG.serviceFee,
    priorityFee: isPickup ? 0 : isPriority ? FEE_CONFIG.priorityFee : 0,
    deliveryDistanceKm,
  }
}

export type OrderStatus =
  | 'pending'
  | 'confirmed'
  | 'preparing'
  | 'ready'
  | 'completed'
  | 'cancelled'
  | 'rejected'

export const TERMINAL_STATUSES: ReadonlySet<OrderStatus> = new Set([
  'completed',
  'cancelled',
  'rejected',
])

const TRANSITIONS: Record<OrderStatus, ReadonlySet<OrderStatus>> = {
  pending: new Set(['confirmed', 'preparing', 'rejected', 'cancelled']),
  confirmed: new Set(['preparing', 'cancelled']),
  preparing: new Set(['ready', 'cancelled']),
  ready: new Set(['completed']),
  completed: new Set(),
  cancelled: new Set(),
  rejected: new Set(),
}

export function canTransition(
  from: OrderStatus,
  to: OrderStatus,
): boolean {
  return TRANSITIONS[from].has(to)
}

export interface OrderItemInput {
  productId: string
  quantity: number
  unit?: string
}
