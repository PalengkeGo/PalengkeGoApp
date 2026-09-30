import { bearerUid, err, handle, supabase } from '../_shared/backend.ts'
import { FIELD_LIMITS, validateOptionalText } from '../_shared/constants.ts'
import { rateLimit } from '../_shared/security.ts'

Deno.serve((req: Request) => handle(req, async (req) => {
  const uid = await bearerUid(req)
  await rateLimit(uid, 'refund', 5)
  const data = await req.json()
  if (typeof data.orderId !== 'string' || !data.orderId) throw err('invalid-argument', 'Order ID required')
  const textError = validateOptionalText(data.reason, FIELD_LIMITS.refundReason, 'reason')
  if (textError) throw err('invalid-argument', textError)
  const decision = (data.decision ?? (data.approve === true ? 'approve' : 'decline'))
  const { error } = await supabase.rpc('refund_market_order', {
    p_uid: uid, p_order_id: data.orderId, p_decision: decision, p_reason: data.reason ?? null,
  })
  if (error) {
    const message = error.message.includes('payment-provider')
      ? 'Online refunds require payment-provider processing. No refund was recorded.'
      : 'Refund action failed. Check the order status and permissions.'
    throw err('failed-precondition', message)
  }
  return {orderId: data.orderId, success: true}
}))
