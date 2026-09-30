import { bearerUid, err, handle, supabase } from '../_shared/backend.ts'
import { FIELD_LIMITS, validateOptionalText } from '../_shared/constants.ts'
import { rateLimit } from '../_shared/security.ts'

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
  const { error } = await supabase.rpc('transition_market_order', {
    p_uid: uid, p_order_id: data.orderId, p_status: status,
    p_remarks: data.remarks ?? null, p_estimated_ready_time: data.estimatedReadyTime ?? null,
  })
  if (error) throw err('failed-precondition', 'The order could not be updated. Refresh and check its current status.')
  return {orderId: data.orderId, status: data.newStatus}
}))
