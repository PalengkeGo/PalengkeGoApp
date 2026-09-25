import { supabase, err } from '../_shared/backend.ts'
import { CANCELLATION_WINDOW_MS } from '../_shared/constants.ts'

export async function applyCancelTransition(
  uid: string,
  orderId: string,
  reason: string | null,
): Promise<void> {
  const { data: order, error } = await supabase
    .from('orders')
    .select('*, customers(user_id)')
    .eq('order_id', orderId)
    .single()

  if (error || !order) {
    throw err('not-found', 'Order not found')
  }

  if (order.order_status !== 'pending') {
    throw err('failed-precondition', 'Only pending orders can be cancelled')
  }

  const customerUserId = (order.customers as any)?.user_id
  if (customerUserId && customerUserId !== uid) {
    throw err('permission-denied', 'Not your order')
  }

  const placedAtMs = new Date(order.created_at).getTime()
  const withinWindow = Date.now() - placedAtMs <= CANCELLATION_WINDOW_MS
  if (!withinWindow) {
    throw err('deadline-exceeded', 'Cancellation window has expired')
  }

  const now = new Date().toISOString()

  await supabase
    .from('orders')
    .update({
      order_status: 'cancelled',
      cancellation_reason: reason,
      updated_at: now,
    })
    .eq('order_id', orderId)

  await supabase.from('order_status_history').insert({
    order_id: orderId,
    previous_status: 'pending',
    new_status: 'cancelled',
    changed_by: uid,
    changed_at: now,
    remarks: reason ?? 'Order cancelled by customer',
  })
}
