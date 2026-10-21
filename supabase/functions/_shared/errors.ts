/**
 * Error type shared by the edge functions. Firebase `HttpsError` codes are
 * preserved so the Flutter client can keep mapping familiar codes; the HTTP
 * status is derived for the Supabase function gateway. PURE module.
 */

export class ApiError extends Error {
  constructor(public readonly code: string, message: string) {
    super(message)
  }
}

export function err(code: string, message: string): ApiError {
  return new ApiError(code, message)
}

/** Expose only known checkout validation failures, never raw database errors. */
export function checkoutError(error: {code?: string; message: string}): ApiError {
  const messages: Record<string, string> = {
    'An active customer account is required': 'Please sign in with an active customer account to place an order.',
    'Your cart is empty': 'Your cart is empty.',
    'This stall is not accepting orders': 'One of the stalls in your cart is closed or unavailable. Remove its items and try again.',
    'Product is unavailable': 'One of the products in your cart is no longer available. Remove it and try again.',
    'Invalid quantity or insufficient stock': 'One of your quantities exceeds current stock. Check the quantities in your cart, including repeated additions.',
    'Piece quantities must be whole numbers': 'Products sold by piece require whole numbers. Change any fractional piece quantities in your cart.',
    'Invalid product price': 'One of the products has no valid price. Please contact its stall holder.',
    'Order items are required': 'Select at least one item from each stall.',
  }
  if (error.code === 'P0001' && messages[error.message]) {
    return err('failed-precondition', messages[error.message])
  }
  if (error.code === 'P0002') {
    return err('failed-precondition', 'A product or stall in your cart no longer exists. Remove unavailable items and try again.')
  }
  return err('internal', 'Checkout encountered a server error. Your order was not placed. Please try again later.')
}

/** Firebase HttpsError code → HTTP status (used by handle() in backend.ts). */
export const HTTP_STATUS: Record<string, number> = {
  unauthenticated: 401,
  unauthorized: 401,
  'permission-denied': 403,
  'invalid-argument': 400,
  'not-found': 404,
  'failed-precondition': 409,
  'already-exists': 409,
  'out-of-range': 400,
  'deadline-exceeded': 408,
  'resource-exhausted': 429,
  internal: 500,
}
