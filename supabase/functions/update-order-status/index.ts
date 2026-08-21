/**
 * Trusted status transition (ported from functions/src/orders.ts
 * updateOrderStatus). Vendor advances orders on their own stall; the allowed
 * graph is the single source of truth (mirrors Flutter OrderStatus).
 * Completion also runs the daily sales rollup in the same transaction.
 */

import { bearerUid, err, handle } from '../_shared/backend.ts'
import { OrderStatus } from '../_shared/constants.ts'
import { applyStatusTransition } from '../_shared/orders.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    const data = await req.json().catch(() => ({}))
    const orderId: string | undefined = data.orderId
    const newStatus: OrderStatus | undefined = data.newStatus
    if (typeof orderId !== 'string') {
      throw err('invalid-argument', 'Missing orderId')
    }
    if (typeof newStatus !== 'string') {
      throw err('invalid-argument', 'Missing newStatus')
    }

    await applyStatusTransition(uid, {
      orderId,
      newStatus,
      remarks: data.remarks ?? null,
      estimatedReadyTime: data.estimatedReadyTime ?? null,
    })

    return { orderId, status: newStatus }
  }),
)
