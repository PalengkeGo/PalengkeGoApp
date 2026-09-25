import { err, handle, supabase } from '../_shared/backend.ts'
import { verifyWebhookSignature } from '../_shared/logic.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const secret = Deno.env.get('PAYMONGO_WEBHOOK_SECRET')
    const raw = new Uint8Array(await req.arrayBuffer())
    const signature = req.headers.get('paymongo-signature')

    if (
      !secret ||
      raw.length === 0 ||
      !signature ||
      !(await verifyWebhookSignature(raw, secret, signature, Date.now()))
    ) {
      throw err('unauthorized', 'Invalid signature')
    }

    let event: any
    try {
      event = JSON.parse(new TextDecoder().decode(raw))
    } catch {
      throw err('invalid-argument', 'Invalid JSON body')
    }

    const type = event?.data?.attributes?.type
    const paymentIntentId = event?.data?.attributes?.data?.attributes?.payment_intent_id

    if (typeof paymentIntentId !== 'string') {
      return { received: true }
    }

    await applyPaymentOutcome(type, paymentIntentId)
    return { received: true }
  }),
)

async function applyPaymentOutcome(type: unknown, paymentIntentId: string): Promise<void> {
  if (type !== 'payment.paid' && type !== 'payment.failed' && type !== 'payment.refunded') {
    return
  }

  const newStatus = type === 'payment.paid' ? 'paid' : type === 'payment.failed' ? 'failed' : 'pending'
  const now = new Date().toISOString()

  await supabase
    .from('orders')
    .update({ payment_status: newStatus, updated_at: now })
    .eq('order_id', paymentIntentId)
}
