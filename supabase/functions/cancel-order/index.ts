/**
 * Customer-facing cancel (ported from functions/src/orders.ts cancelOrder) —
 * thin wrapper so callers don't need to know status names.
 */

import { bearerUid, err, handle } from '../_shared/backend.ts'
import { applyStatusTransition } from '../_shared/orders.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    const data = await req.json().catch(() => ({}))
    if (typeof data.orderId !== 'string') {
      throw err('invalid-argument', 'Missing orderId')
    }

    await applyStatusTransition(uid, {
      orderId: data.orderId,
      newStatus: 'cancelled',
      remarks: data.reason ?? null,
    })

    return { orderId: data.orderId, status: 'cancelled' }
  }),
)
