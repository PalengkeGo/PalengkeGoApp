import { bearerUid, err, handle, roleOf, stallOwnerUid, supabase } from '../_shared/backend.ts'
import { rateLimit } from '../_shared/security.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    await rateLimit(uid, 'processRefund', 5)

    const role = await roleOf(uid)
    const data = await req.json().catch(() => ({}))
    const orderId: unknown = data.orderId
    const decision: unknown = data.decision ?? (data.approve ? 'approve' : 'decline')

    if (typeof orderId !== 'string' || orderId.length === 0) {
      throw err('invalid-argument', 'Missing orderId')
    }
    if (decision !== 'approve' && decision !== 'decline') {
      throw err('invalid-argument', 'decision must be "approve" or "decline"')
    }

    const { data: order, error } = await supabase
      .from('orders')
      .select('*')
      .eq('order_id', orderId)
      .single()

    if (error || !order) {
      throw err('not-found', 'Order not found')
    }

    const ownerUid = await stallOwnerUid(order.stall_holder_id)
    if (role !== 'admin' && ownerUid !== uid) {
      throw err('permission-denied', 'Only the stall owner or an admin can process this refund')
    }

    const now = new Date().toISOString()

    if (decision === 'decline') {
      await supabase.from('order_status_history').insert({
        order_id: orderId,
        previous_status: order.order_status,
        new_status: order.order_status,
        changed_by: uid,
        changed_at: now,
        remarks: 'Refund request declined',
      })
      return { orderId, processed: 'declined' }
    }

    // Approve refund
    await supabase
      .from('orders')
      .update({
        payment_status: 'failed',
        order_status: 'cancelled',
        cancellation_reason: 'Refund approved by vendor/admin',
        updated_at: now,
      })
      .eq('order_id', orderId)

    await supabase.from('order_status_history').insert({
      order_id: orderId,
      previous_status: order.order_status,
      new_status: 'cancelled',
      changed_by: uid,
      changed_at: now,
      remarks: 'Refund approved',
    })

    return { orderId, processed: 'approved' }
  }),
)