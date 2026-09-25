import { bearerUid, err, handle, roleOf, supabase } from '../_shared/backend.ts'
import { rateLimit as rateL } from '../_shared/security.ts'
import { normalizePaymentMethod } from '../_shared/logic.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    await rateL(uid, 'createPaymentIntent', 10)

    const data = await req.json().catch(() => ({}))
    const orderId: unknown = data.orderId
    const method = normalizePaymentMethod(data.paymentMethod)
    if (typeof orderId !== 'string' || orderId.length === 0) {
      throw err('invalid-argument', 'Missing orderId')
    }
    if (!method) {
      throw err('invalid-argument', 'paymentMethod must be one of: card, gcash, maya')
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

    if (order.order_status !== 'pending') {
      throw err('failed-precondition', 'Only pending orders can be paid')
    }
    if (order.payment_status === 'paid') {
      throw err('already-exists', 'Order is already paid')
    }

    const now = new Date().toISOString()
    await supabase
      .from('orders')
      .update({ payment_status: 'pending', updated_at: now })
      .eq('order_id', orderId)

    const totalAmount = typeof order.total_amount === 'number' ? order.total_amount : 0
    const amountCents = Math.round(totalAmount * 100)
    if (amountCents < 100) {
      throw err('out-of-range', 'Amount must be at least PHP 1.00')
    }

    return {
      intentId: 'pi_' + orderId.replace(/-/g, '').slice(0, 16),
      clientKey: 'client_key_' + orderId.replace(/-/g, '').slice(0, 16),
    }
  }),
)