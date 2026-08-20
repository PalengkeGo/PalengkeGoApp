/**
 * Trusted order placement (ported from functions/src/orders.ts placeOrder).
 * Recomputes prices and stock server-side — the client may NOT dictate the
 * price or write below-zero stock. Deducts stock atomically inside a
 * transaction and stamps an immutable audit log.
 */

import { bearerUid, db, err, FieldValue, handle, isBlocked, roleOf, assertRole } from '../_shared/backend.ts'
import {
  FIELD_LIMITS,
  OrderItemInput,
  PAYMENT_METHODS,
  computeFees,
  validateOptionalText,
} from '../_shared/constants.ts'
import { rateLimit } from '../_shared/security.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req, true)
    const role = await roleOf(uid)
    assertRole(role, ['customer'])
    if (await isBlocked(uid)) {
      throw err('permission-denied', 'Your account is blocked')
    }
    await rateLimit(db, uid, 'placeOrder', 10)

    const data = await req.json().catch(() => ({}))
    const stallId: string | undefined = data.stallId
    const items: OrderItemInput[] = data.items

    if (typeof stallId !== 'string' || stallId.length === 0) {
      throw err('invalid-argument', 'Missing stallId')
    }
    if (!Array.isArray(items) || items.length === 0) {
      throw err('invalid-argument', 'Order must contain items')
    }
    if (
      typeof data.fulfillmentMethod !== 'string' ||
      !['pickup', 'delivery'].includes(data.fulfillmentMethod)
    ) {
      throw err('invalid-argument', 'Invalid fulfillmentMethod')
    }

    const paymentMethod: string = data.paymentMethod ?? 'cod'
    if (!PAYMENT_METHODS.includes(paymentMethod as never)) {
      throw err('invalid-argument', 'Invalid paymentMethod')
    }
    const textError =
      validateOptionalText(data.customerName, FIELD_LIMITS.customerName, 'customerName') ??
      validateOptionalText(data.deliveryAddress, FIELD_LIMITS.deliveryAddress, 'deliveryAddress') ??
      validateOptionalText(data.notes, FIELD_LIMITS.notes, 'notes')
    if (textError) {
      throw err('invalid-argument', textError)
    }

    const stallRef = db.collection('vendorStalls').doc(stallId)
    const stallSnap = await stallRef.get()
    if (!stallSnap.exists) {
      throw err('not-found', 'Stall not found')
    }
    const stall = stallSnap.data()!

    const orderRef = db.collection('orders').doc()
    const timestamp = FieldValue.serverTimestamp()

    interface ResolvedItem {
      productId: string
      name: string
      price: number
      unit: string
      quantity: number
      imageUrl: string
    }
    const resolved: ResolvedItem[] = []

    await db.runTransaction(async (tx: any) => {
      // Server-side truth: resolve each product, locking its stock + price
      // inside the transaction so two simultaneous orders cannot oversell.
      for (const item of items) {
        const prodSnap = await tx.get(
          db.collection('vendorStalls').doc(stallId).collection('products').doc(item.productId),
        )
        if (!prodSnap.exists) {
          throw err('not-found', `Product ${item.productId} not found`)
        }
        const p = prodSnap.data()!
        if (p.isActive !== true) {
          throw err('failed-precondition', `Product is not active: ${item.productId}`)
        }
        const stock = typeof p.stockQuantity === 'number' ? p.stockQuantity : 0
        // Number.isFinite guards NaN/Infinity, which pass <= / > comparisons.
        const quantity =
          typeof item.quantity === 'number' && Number.isFinite(item.quantity)
            ? item.quantity
            : 0
        if (quantity <= 0 || quantity > stock) {
          throw err('out-of-range', `Insufficient stock for ${item.productId}`)
        }
        resolved.push({
          productId: item.productId,
          name: p.name ?? '',
          price: p.price ?? 0,
          unit: item.unit ?? p.unit ?? 'kg',
          quantity,
          imageUrl: p.imageUrl ?? '',
        })
        tx.update(prodSnap.ref, { stockQuantity: stock - quantity })
      }

      const itemsTotal = resolved.reduce((sum, i) => sum + i.price * i.quantity, 0)
      // Fees are derived server-side (mirrors FeeConfig) — the client never
      // dictates amounts on the trusted path.
      const isPriority = data.isPriority === true
      const { deliveryFee, serviceFee, priorityFee } = computeFees(
        data.fulfillmentMethod,
        isPriority,
      )

      tx.set(orderRef, {
        customerUid: uid,
        stallId,
        vendorName: stall.name ?? '',
        vendorImage: stall.avatarImage ?? '',
        customerName: data.customerName ?? 'Customer',
        status: 'pending',
        paymentStatus: 'pending',
        paymentMethod,
        fulfillmentMethod: data.fulfillmentMethod,
        deliveryAddress: data.deliveryAddress ?? null,
        deliveryFee,
        serviceFee,
        isPriority,
        priorityFee,
        notes: data.notes ?? null,
        placedAt: timestamp,
        updatedAt: timestamp,
        estimatedReadyTime: data.estimatedReadyTime ?? null,
        cancellationReason: null,
        items: resolved.map((i) => ({
          productId: i.productId,
          productName: i.name,
          quantity: i.quantity,
          unitPrice: i.price,
          unit: i.unit,
          image: i.imageUrl,
        })),
      })

      tx.set(orderRef.collection('statusHistory').doc(), {
        orderId: orderRef.id,
        previousStatus: null,
        newStatus: 'pending',
        changedBy: 'system',
        changedAt: timestamp,
        remarks: null,
      })
    })

    return { orderId: orderRef.id }
  }),
)
