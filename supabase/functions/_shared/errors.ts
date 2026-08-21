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
