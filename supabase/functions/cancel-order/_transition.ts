import { supabase, err } from '../_shared/backend.ts'

export async function applyCancelTransition(uid: string, orderId: string, reason: string | null): Promise<void> {
  const { error } = await supabase.rpc('transition_market_order', {
    p_uid: uid, p_order_id: orderId, p_status: 'cancelled',
    p_remarks: reason, p_customer_cancel: true,
  })
  if (error) {
    if (error.message.includes('window')) throw err('deadline-exceeded', 'Cancellation window has expired')
    throw err('failed-precondition', 'Only your pending orders can be cancelled within five minutes.')
  }
}
