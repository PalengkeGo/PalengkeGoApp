/**
 * Order helpers shared across Supabase Edge Functions.
 *
 * Ported from functions/src/orders.ts — stock checks, status transitions,
 * and restock logic. PURE where possible; transaction code stays in each
 * handler (place-order, update-order-status, cancel-order) to keep locks tight.
 */

import { CANCELLATION_WINDOW_MS, canTransition, TERMINAL_STATUSES } from './constants.ts'

export interface ResolvedItem {
  productId: string
  name: string
  price: number
  unit: string
  quantity: number
  imageUrl: string
}

/**
 * Validates quantity against available stock.
 * Returns null on success, error code on failure.
 */
export function validateQuantity(
  quantity: unknown,
  stock: number,
): string | null {
  if (typeof quantity !== 'number' || !Number.isFinite(quantity) || quantity <= 0) {
    return 'Quantity must be a positive number'
  }
  if (quantity > stock) return 'Insufficient stock'
  return null
}

/**
 * Returns true if the status transition is allowed.
 * Terminal statuses are immutable; same-status re-record bypasses the graph.
 */
export function isAllowedTransition(from: string, to: string): boolean {
  if ((TERMINAL_STATUSES as ReadonlySet<string>).has(from)) return false
  if (from === to) return true // re-record (e.g. updating estimatedReadyTime)
  return canTransition(from as any, to as any)
}

/**
 * Checks if the cancellation window is still open.
 */
export function withinCancelWindow(placedAt: unknown): boolean {
  const ms = (placedAt as any)?.toMillis?.() as number | undefined
  if (typeof ms !== 'number' || Number.isNaN(ms)) return false
  return Date.now() - ms <= CANCELLATION_WINDOW_MS
}
