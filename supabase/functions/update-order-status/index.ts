import { bearerUid, err, handle, isBlocked, roleOf, stallOwnerUid, supabase } from '../_shared/backend.ts'
import { canTransition, FIELD_LIMITS, TERMINAL_STATUSES, validateOptionalText } from '../_shared/constants.ts'
import { rateLimit } from '../_shared/security.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    if (await isBlocked(uid)) {
      throw err('permission-denied', 'Your account is blocked')
    }
    await rateLimit(uid, 'orderStatus', 60)

    const data = await req.json().catch(() => ({}))
    const orderId: string | undefined = data.orderId
    const newStatus: string | undefined = data.newStatus
    if (typeof orderId !== 'string' || !orderId) {
      throw err('invalid-argument', 'Missing orderId')
    }
    if (typeof newStatus !== 'string' || !newStatus) {
      throw err('invalid-argument', 'Missing newStatus')
    }

    const textError = validateOptionalText(data.remarks, FIELD_LIMITS.remarks, 'remarks')
    if (textError) {
      throw err('invalid-argument', textError)
    }

    const { data: order, error } = await supabase
      .from('orders')
      .select('*, customers(user_id)')
      .eq('order_id', orderId)
      .single()

    if (error || !order) {
      throw err('not-found', 'Order not found')
    }

    const prevStatus = (order.order_status ?? 'pending') as any
    if (TERMINAL_STATUSES.has(prevStatus)) {
      throw err('failed-precondition', `Order is already ${prevStatus} and can no longer change`)
    }

    const isReRecord = prevStatus === newStatus
    if (!isReRecord && !canTransition(prevStatus, newStatus as any)) {
      throw err('failed-precondition', `Cannot transition order from ${prevStatus} to ${newStatus}`)
    }

    const now = new Date().toISOString()
    const updateData: Record<string, any> = {
      order_status: newStatus,
      updated_at: now,
    }
    if (data.estimatedReadyTime) {
      updateData.estimated_ready_time = data.estimatedReadyTime
    }

    const { error: updateErr } = await supabase
      .from('orders')
      .update(updateData)
      .eq('order_id', orderId)

    if (updateErr) {
      throw err('internal', 'Failed to update order status')
    }

    await supabase.from('order_status_history').insert({
      order_id: orderId,
      previous_status: prevStatus,
      new_status: newStatus,
      changed_by: uid,
      changed_at: now,
      remarks: data.remarks ?? null,
    })

    return { orderId, status: newStatus }
  }),
)