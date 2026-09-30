import { bearerUid, err, handle, isBlocked, supabase } from '../_shared/backend.ts'
import { computeFees, FIELD_LIMITS, PAYMENT_METHODS, validateOptionalText } from '../_shared/constants.ts'
import { rateLimit } from '../_shared/security.ts'

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
    console.error('Checkout transaction failed', error.code)
    throw err('failed-precondition', 'Order could not be placed. Refresh your cart and check stock and stall availability.')
  }
  return { orders }
}))
