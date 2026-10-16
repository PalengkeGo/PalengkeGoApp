import { bearerUid, err, handle, supabase } from '../_shared/backend.ts'
import { rateLimit as rateL } from '../_shared/security.ts'
import { normalizePaymentMethod } from '../_shared/logic.ts'
import { PAYMONGO_API_URL } from '../_shared/constants.ts'

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
      .select('*')
      .eq('order_id', orderId)
      .single()

    if (error || !order) {
      throw err('not-found', 'Order not found')
    }

    const { data: customer } = await supabase
      .from('customers')
      .select('user_id')
      .eq('customer_id', order.customer_id)
      .maybeSingle()
    const customerUserId = customer?.user_id
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
    if (amountCents < 2000) {
      throw err('out-of-range', 'Online e-wallet payments require an order total of at least PHP 20.00')
    }

    const secretKey = Deno.env.get('PAYMONGO_SECRET_KEY')
    if (!secretKey || !secretKey.startsWith('sk_')) {
      throw err('failed-precondition', 'PayMongo secret key is not configured on the server')
    }

    // PayMongo accepts `paymaya` for Maya in both the intent allow-list and
    // the PaymentMethod resource, even though the app accepts `maya`.
    const paymongoMethod = method === 'maya' ? 'paymaya' : method
    const paymongoResponse = await fetch(`${PAYMONGO_API_URL}/payment_intents`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${btoa(`${secretKey}:`)}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': `palengkego-${orderId}-${paymongoMethod}`,
      },
      body: JSON.stringify({
        data: {
          attributes: {
            amount: amountCents,
            currency: 'PHP',
            payment_method_allowed: [paymongoMethod],
            capture_type: 'automatic',
          },
        },
      }),
    })
    const paymongoBody = await paymongoResponse.json().catch(() => ({}))
    if (!paymongoResponse.ok) {
      const detail = paymongoBody?.errors?.[0]?.detail
      throw err('failed-precondition', `PayMongo could not create the payment intent${detail ? `: ${detail}` : ''}`)
    }
    const intent = paymongoBody?.data
    const intentId = intent?.id
    const clientKey = intent?.attributes?.client_key
    if (typeof intentId !== 'string' || typeof clientKey !== 'string') {
      throw err('internal', 'PayMongo returned an invalid payment intent')
    }
    const { error: linkError } = await supabase
      .from('orders')
      .update({ payment_intent_id: intentId, updated_at: new Date().toISOString() })
      .eq('order_id', orderId)
    if (linkError) throw err('internal', 'Unable to link the payment to the order')
    return { intentId, clientKey }
  }),
)
