/**
 * Customer-facing cancel (Supabase Edge Function port of functions/src/orders.ts cancelOrder).
 * Thin wrapper so callers don't need to know status names.
 */

import { bearerUid, err, handle } from '../_shared/backend.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    const data = await req.json()
    if (typeof data.orderId !== 'string') {
      throw err('invalid-argument', 'Missing orderId')
    }

    // Delegate to the update-order-status handler with newStatus='cancelled'
    // Re-use the same function logic by calling via internal import or duplicate code
    // For simplicity, we duplicate the minimal cancel logic here:

    const { applyCancelTransition } = await import('./_transition.ts')
    await applyCancelTransition(uid, data.orderId, data.reason ?? null)

    return { orderId: data.orderId, status: 'cancelled' }
  }),
)