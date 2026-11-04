import { bearerUid, err, handle, isBlocked, supabase } from '../_shared/backend.ts'
import { computeFees, FIELD_LIMITS, PAYMENT_METHODS, validateOptionalText } from '../_shared/constants.ts'
import { rateLimit } from '../_shared/security.ts'
import { checkoutError } from '../_shared/errors.ts'
import { sendPushToUsers } from '../_shared/push.ts'

Deno.serve((req: Request) => handle(req, async (req) => {
  const uid = await bearerUid(req, true)
  if (await isBlocked(uid)) throw err('permission-denied', 'Your account is blocked')
  await rateLimit(uid, 'placeOrder', 10)
  const data = await req.json()
  const groups = data.lineItemsByStall
  if (!groups || typeof groups !== 'object' || Array.isArray(groups) || Object.keys(groups).length === 0) {
    throw err('invalid-argument', 'Your cart is empty')
  }
  for (const items of Object.values(groups)) {
    if (!Array.isArray(items) || items.length === 0 || items.some((item) =>
      typeof item.productId !== 'string' || !item.productId ||
      typeof item.quantity !== 'number' || !Number.isFinite(item.quantity) || item.quantity <= 0)) {
      throw err('invalid-argument', 'Invalid product or quantity')
    }
  }
  const isPickup = data.isPickup === true
  const paymentMethod = data.paymentMethod ?? 'cod'
  if (!PAYMENT_METHODS.includes(paymentMethod)) throw err('invalid-argument', 'Invalid payment method')
  for (const [field, limit] of Object.entries({customerName: FIELD_LIMITS.customerName,
    customerPhone: 30, deliveryAddress: FIELD_LIMITS.deliveryAddress})) {
    const error = validateOptionalText(data[field], limit, field)
    if (error) throw err('invalid-argument', error)
  }
  for (const note of Object.values(data.vendorNotes ?? {})) {
    const error = validateOptionalText(note, FIELD_LIMITS.notes, 'notes')
    if (error) throw err('invalid-argument', error)
  }
  if (!isPickup && (typeof data.deliveryAddress !== 'string' || !data.deliveryAddress.trim())) {
    throw err('invalid-argument', 'Delivery address required')
  }
  const lat = isPickup ? null : data.deliveryLatitude
  const lng = isPickup ? null : data.deliveryLongitude
  if ((lat != null || lng != null) && (!Number.isFinite(lat) || !Number.isFinite(lng) ||
    Math.abs(lat) > 90 || Math.abs(lng) > 180)) throw err('invalid-argument', 'Invalid delivery location')
  const fees = computeFees(isPickup ? 'pickup' : 'delivery', data.isPriority === true, lat, lng)
  const { data: orders, error } = await supabase.rpc('place_market_orders', {
    p_uid: uid,
    p_data: {...data, isPickup, paymentMethod, fees,
      deliveryAddress: isPickup ? null : data.deliveryAddress,
      deliveryLatitude: lat, deliveryLongitude: lng},
  })
  if (error) {
    console.error('Checkout transaction failed', {code: error.code, message: error.message})
    throw checkoutError(error)
  }
  // Orders are already committed here. Notify each stall holder without
  // allowing an FCM outage to make checkout appear to have failed.
  try {
    const stallIds = [...new Set(Object.keys(groups))]
    const { data: stalls, error: stallsError } = await supabase.from('stall_holders')
      .select('stall_holder_id,user_id').in('stall_holder_id', stallIds)
    if (stallsError) throw stallsError
    const byStall = new Map((stalls ?? []).map((stall) => [String(stall.stall_holder_id), String(stall.user_id)]))
    const committedOrders = Array.isArray(orders) ? orders as Array<Record<string, unknown>> : []
    await Promise.all(committedOrders.map((order) => {
      const stallId = String(order.stall_holder_id ?? '')
      return sendPushToUsers(
        byStall.has(stallId) ? [byStall.get(stallId)!] : [],
        'New incoming order',
        `You received order ${String(order.order_id ?? '')}. Open PalengkeGo to review it.`,
        'incoming_order',
        String(order.order_id ?? ''),
      )
    }))
  } catch (pushError) {
    console.error('Could not prepare incoming order notifications:', pushError)
  }
  return { orders }
}))
