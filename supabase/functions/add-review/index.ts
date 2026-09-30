import { bearerUid, err, handle, isBlocked, supabase } from '../_shared/backend.ts'
import { FIELD_LIMITS, validateOptionalText } from '../_shared/constants.ts'
import { rateLimit } from '../_shared/security.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    if (await isBlocked(uid)) {
      throw err('permission-denied', 'Your account is blocked')
    }
    await rateLimit(uid, 'addReview', 10)

    const data = await req.json().catch(() => ({}))
    const stallId: unknown = data.stallId
    const orderId: unknown = data.orderId
    const rating: unknown = data.rating
    const comment: string | undefined = data.comment

    if (typeof stallId !== 'string' || typeof orderId !== 'string') {
      throw err('invalid-argument', 'stallId and orderId required')
    }
    if (typeof rating !== 'number' || !Number.isInteger(rating) || rating < 1 || rating > 5) {
      throw err('invalid-argument', 'rating must be between 1 and 5')
    }

    const textError = validateOptionalText(comment, FIELD_LIMITS.reviewComment, 'comment')
    if (textError) {
      throw err('invalid-argument', textError)
    }

    // Check order
    const { data: order, error } = await supabase
      .from('orders')
      .select('*')
      .eq('order_id', orderId)
      .single()

    if (error || !order) {
      throw err('not-found', 'Order not found')
    }

    const { data: customer, error: customerError } = await supabase.from('customers')
      .select('user_id').eq('customer_id', order.customer_id).single()
    if (customerError || customer?.user_id !== uid) throw err('permission-denied', 'Not your order')
    if (order.stall_holder_id !== stallId) throw err('invalid-argument', 'Order does not belong to this stall')
    if (!['delivered', 'completed'].includes(order.order_status)) {
      throw err('failed-precondition', 'Only completed orders can be reviewed')
    }

    // Insert or update rating
    const { data: ratingRow, error: ratingErr } = await supabase
      .from('ratings')
      .upsert({
        customer_id: order.customer_id,
        stall_holder_id: order.stall_holder_id,
        order_id: orderId,
        score: Math.round(rating),
        comment: comment ?? null,
      }, { onConflict: 'order_id' })
      .select('rating_id')
      .single()

    if (ratingErr) {
      console.error('Rating insert error:', ratingErr)
      throw err('internal', 'Failed to save review')
    }

    return { ratingId: ratingRow?.rating_id, success: true }
  }),
)