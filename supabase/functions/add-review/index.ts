/**
 * Trusted review creation (ported from functions/src/reviews.ts addReview).
 *
 * The customer must be the owner of a completed order for the vendor. The
 * stall rating aggregate is recomputed in the SAME transaction so the
 * average/count can never drift from the raw review set.
 *
 * One-review-per-order is enforced WITHOUT a query-then-write race: the rating
 * doc id is deterministic (`ratings/{orderId}_{customerId}`), and the doc is
 * created inside the transaction only if it does not already exist. Two
 * concurrent submissions collide on the same id — one commits, the other sees
 * the existing doc and is rejected.
 */

import { bearerUid, db, err, FieldValue, handle, isBlocked } from '../_shared/backend.ts'
import { FIELD_LIMITS, validateOptionalText } from '../_shared/constants.ts'
import { rateLimit } from '../_shared/security.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    // Audit 2026-08-23 M4: parity with functions/src/reviews.ts — a block
    // cuts the user off from every trusted path, refused before rate-limit
    // quota is spent.
    if (await isBlocked(uid)) {
      throw err('permission-denied', 'Your account is blocked')
    }
    await rateLimit(db, uid, 'addReview', 10)

    const data = await req.json().catch(() => ({}))
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
    if (
      typeof rating !== 'number' ||
      rating < 1 ||
      rating > 5 ||
      !Number.isInteger(rating * 10)
    ) {
      throw err('invalid-argument', 'rating must be 1..5 (0.1 steps)')
    }
    const textError =
      validateOptionalText(comment, FIELD_LIMITS.reviewComment, 'comment') ??
      validateOptionalText(productName, FIELD_LIMITS.reviewProductName, 'productName') ??
      validateOptionalText(data.customerName, FIELD_LIMITS.customerName, 'customerName')
    if (textError) {
      throw err('invalid-argument', textError)
    }

    // Verify the order belongs to this customer and is completed.
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

    // Fast pre-check for reviews written before deterministic ids existed
    // (legacy random-id docs). The authoritative check is the transactional
    // create below.
    const legacy = await db
      .collection('ratings')
      .where('orderId', '==', orderId)
      .where('customerId', '==', uid)
      .limit(1)
      .get()
    if (!legacy.empty) {
      throw err('already-exists', 'This order was already reviewed')
    }

    // Deterministic id: one review per (order, customer) is guaranteed by the
    // document identity itself, not by a check-then-write sequence.
    const ratingRef = db.collection('ratings').doc(`${orderId}_${uid}`)

    await db.runTransaction(async (tx: any) => {
      const existing = await tx.get(ratingRef)
      if (existing.exists) {
        throw err('already-exists', 'This order was already reviewed')
      }

      // Lock the stall doc: read + write in the same transaction.
      const stallRef = db.collection('vendorStalls').doc(stallId)
      const stallSnap = await tx.get(stallRef)
      const stall = stallSnap.exists ? stallSnap.data() ?? {} : {}
      const currentRating = typeof stall.averageRating === 'number'
        ? stall.averageRating
        : 0
      const currentCount = typeof stall.totalRatings === 'number'
        ? stall.totalRatings
        : 0

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

      await tx.update(stallRef, {
        averageRating: newAverage,
        totalRatings: newCount,
      })
    })

    return { ratingId: ratingRef.id }
  }),
)
