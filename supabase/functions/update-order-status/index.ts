import { bearerUid, err, handle, supabase } from '../_shared/backend.ts'
import { FIELD_LIMITS, validateOptionalText } from '../_shared/constants.ts'
import { rateLimit } from '../_shared/security.ts'
import { sendPushToUsers } from '../_shared/push.ts'

Deno.serve((req: Request) => handle(req, async (req) => {
  const uid = await bearerUid(req)
  await rateLimit(uid, 'orderStatus', 60)
  const data = await req.json()
  if (typeof data.orderId !== 'string' || !data.orderId || typeof data.newStatus !== 'string') {
    throw err('invalid-argument', 'Order ID and status required')
  }
  const textError = validateOptionalText(data.remarks, FIELD_LIMITS.remarks, 'remarks')
  if (textError) throw err('invalid-argument', textError)
  const status = data.newStatus === 'completed' ? 'delivered' :
    data.newStatus === 'outForDelivery' ? 'out_for_delivery' : data.newStatus
  let customerUid: string | null = null
  if (status === 'delivered') {
    const { data: order, error: orderError } = await supabase.from('orders')
      .select('customer_id').eq('order_id', data.orderId).maybeSingle()
    if (orderError) throw orderError
    if (order?.customer_id) {
      const { data: customer, error: customerError } = await supabase.from('customers')
        .select('user_id').eq('customer_id', order.customer_id).maybeSingle()
      if (customerError) throw customerError
      customerUid = customer?.user_id ? String(customer.user_id) : String(order.customer_id)
    }
  }
  const { error } = await supabase.rpc('transition_market_order', {
    p_uid: uid, p_order_id: data.orderId, p_status: status,
    p_remarks: data.remarks ?? null, p_estimated_ready_time: data.estimatedReadyTime ?? null,
  })
  if (error) throw err('failed-precondition', 'The order could not be updated. Refresh and check its current status.')
  if (status === 'delivered' && customerUid) {
    await sendPushToUsers([customerUid], 'Order completed', `Order ${data.orderId} has been delivered.`, 'order_completed', data.orderId)
  }
  return {orderId: data.orderId, status: data.newStatus}
}))
