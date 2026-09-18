/**
 * Trusted review creation (Supabase Edge Function port of functions/src/reviews.ts addReview).
 *
 * One-review-per-order enforced deterministically. Stall rating aggregate recomputed in the same transaction.
 */

import { db, bearerUid, err, FieldValue, handle } from '../_shared/backend.ts'
import { FIELD_LIMITS, validateOptionalText } from '../_shared/constants.ts'
import { rateLimit } from '../_shared/security.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    if (await isBlocked(uid)) {
      throw err('permission-denied', 'Your account is blocked')
    }
    await rateLimit(uid, 'addReview', 10)

    const data = await req.json()
    const stallId: unknown = data.stallId
    const orderId: unknown = data.orderId
    const rating: unknown = data.rating
    const comment: string | undefined = data.comment
    const reviewType: string | undefined = data.reviewType
    const productId: string | undefined = data.productId
    const productName: string | undefined = data.productName

    if (typeof stallId !== 'string' || typeof orderId !== 'string') {
      throw err('invalid-argument', 'stallId and orderId required')
    }
    if (typeof rating !== 'number' || rating < 1 || rating > 5 || !Number.isInteger(rating * 10)) {
      throw err('invalid-argument', 'rating must be 1..5 (0.1 steps)')
    }

    const textError =
      validateOptionalText(comment, FIELD_LIMITS.reviewComment, 'comment') ??
      validateOptionalText(productName, FIELD_LIMITS.reviewProductName, 'productName') ??
      validateOptionalText(data.customerName, FIELD_LIMITS.customerName, 'customerName')
    if (textError) {
      throw err('invalid-argument', textError)
    }

    const orderSnap = await db.collection('orders').doc(orderId).get()
    if (!orderSnap.exists) {
      throw err('not-found', 'Order not found')
    }
    const order = orderSnap.data()!
    if (order.customerUid !== uid) {
      throw err('permission-denied', 'Not your order')
    }
    if (order.stallId !== stallId) {
      throw err('invalid-argument', 'Order does not belong to this stall')
    }
    if (order.status !== 'completed') {
      throw err('failed-precondition', 'Only completed orders can be reviewed')
    }

    // Deterministic id: one review per (order, customer)
    const ratingRef = db.collection('ratings').doc(`${orderId}_${uid}`)

    await db.runTransaction(async (tx) => {
      const existing = await tx.get(ratingRef)
      if (existing.exists) {
        throw err('already-exists', 'This order was already reviewed')
      }

      const stallRef = db.collection('stallCatalog').doc(stallId)
      const stallSnap = await tx.get(stallRef)
      const stall = stallSnap.exists ? stallSnap.data() ?? {} : {}
      const currentRating = typeof stall.averageRating === 'number' ? stall.averageRating : 0
      const currentCount = typeof stall.totalRatings === 'number' ? stall.totalRatings : 0

      const newCount = currentCount + 1
      const newAverage = (currentRating * currentCount + rating) / newCount

      await tx.set(ratingRef, {
        vendorId: stallId,
        customerId: uid,
        customerName: data.customerName ?? 'Customer',
        rating,
        comment: comment ?? '',
        date: FieldValue.serverTimestamp(),
        orderId,
        reviewType: reviewType === 'product' ? 'product' : 'vendor',
        productName: productName ?? null,
      })

      await tx.set(stallRef, { averageRating: newAverage, totalRatings: newCount }, { merge: true })
    })

    return { ratingId: ratingRef.id }
  }),
)

async function isBlocked(uid: string): Promise<boolean> {
  const snap = await db.collection('users').doc(uid).get()
  return snap.exists ? snap.data()?.isBlocked === true : false
}