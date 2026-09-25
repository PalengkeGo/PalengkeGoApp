import { bearerUid, err, handle, supabase } from '../_shared/backend.ts'
import { FIELD_LIMITS, validateOptionalText } from '../_shared/constants.ts'
import { rateLimit } from '../_shared/security.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    await rateLimit(uid, 'requestRefund', 5)

    const data = await req.json().catch(() => ({}))
    const orderId: unknown = data.orderId
    if (typeof orderId !== 'string' || orderId.length === 0) {
      throw err('invalid-argument', 'Missing orderId')
    }

    const reasonError = validateOptionalText(data.reason, FIELD_LIMITS.refundReason, 'reason')
    if (reasonError) {
      throw err('invalid-argument', reasonError)
    }

    const { data: order, error } = await supabase
      .from('orders')
      .select('*, customers(user_id)')
      .eq('order_id', orderId)
      .single()

    if (error || !order) {
      throw err('not-found', 'Order not found')
    }

    const customerUserId = (order.customers as any)?.user_id
    if (customerUserId && customerUserId !== uid) {
      throw err('permission-denied', 'Not your order')
    }

    if (order.payment_status !== 'paid') {
      throw err('failed-precondition', 'Only fully paid orders can be refunded')
    }

    const now = new Date().toISOString()

    const { error: updateErr } = await supabase
      .from('orders')
      .update({
        payment_status: 'pending',
        cancellation_reason: data.reason ? `Refund requested: ${data.reason}` : 'Refund requested',
        updated_at: now,
      })
      .eq('order_id', orderId)

    if (updateErr) {
      throw err('internal', 'Failed to update order payment status')
    }

    await supabase.from('order_status_history').insert({
      order_id: orderId,
      previous_status: order.order_status,
      new_status: order.order_status,
      changed_by: uid,
      changed_at: now,
      remarks: data.reason ? `Refund requested: ${data.reason}` : 'Refund requested by customer',
    })

    return { orderId, success: true }
  }),
)