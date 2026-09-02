import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import {
  CANCELLATION_WINDOW_MS,
  OrderStatus,
  OrderItemInput,
  TERMINAL_STATUSES,
  canTransition,
  computeFees,
  isCashPayment,
  PAYMENT_METHODS,
  validateOptionalText,
  FIELD_LIMITS,
} from './constants';
import { APP_CHECK_ENFORCED, isBlocked, rateLimit } from './security';

const db = admin.firestore();

async function roleOf(uid: string): Promise<string | null> {
  const snap = await db.collection('users').doc(uid).get();
  return snap.exists ? (snap.data()?.role as string | null) : null;
}

export async function stallOwnerUid(stallId: string): Promise<string | null> {
  const snap = await db.collection('vendorStalls').doc(stallId).get();
  return snap.exists ? (snap.data()?.ownerUid as string | null) : null;
}

function assertRole(role: string | null, expected: string[]): void {
  if (!role || !expected.includes(role)) {
    throw new HttpsError(
      'permission-denied',
      'You do not have permission for this operation',
    );
  }
}

export interface ResolvedItem {
  productId: string;
  name: string;
  price: number;
  unit: string;
  quantity: number;
  imageUrl: string;
}

/**
 * Trusted order placement.
 * Recomputes prices and stock server-side — the client may NOT dictate the
 * price or write below-zero stock. Deducts stock atomically inside a
 * transaction and stamps an immutable audit log.
 */
export const placeOrder = onCall(
  { enforceAppCheck: APP_CHECK_ENFORCED, timeoutSeconds: 30 },
  async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  // Server-side email-verification gate (audit 2026-08-23 M1). Previously
  // this check lived ONLY in the Supabase place-order edge port — which the
  // app never calls — leaving the live path gated client-side only. Google
  // sign-in accounts always carry email_verified = true, so they pass
  // naturally; email/password registrations must verify first.
  if (request.auth?.token?.email_verified !== true) {
    throw new HttpsError(
      'failed-precondition',
      'Verify your email before placing orders',
    );
  }
  const role = await roleOf(uid);
  assertRole(role, ['customer']);
  if (await isBlocked(uid)) {
    throw new HttpsError('permission-denied', 'Your account is blocked');
  }
  await rateLimit(uid, 'placeOrder', 10);

  const data = request.data ?? {};
  const stallId: string | undefined = data.stallId;
  const items: OrderItemInput[] = data.items;

  if (typeof stallId !== 'string' || stallId.length === 0) {
    throw new HttpsError('invalid-argument', 'Missing stallId');
  }
  if (!Array.isArray(items) || items.length === 0) {
    throw new HttpsError('invalid-argument', 'Order must contain items');
  }
  if (
    typeof data.fulfillmentMethod !== 'string' ||
    !['pickup', 'delivery'].includes(data.fulfillmentMethod)
  ) {
    throw new HttpsError('invalid-argument', 'Invalid fulfillmentMethod');
  }

  const paymentMethod: string = data.paymentMethod ?? 'cod';
  if (!PAYMENT_METHODS.includes(paymentMethod as never)) {
    throw new HttpsError('invalid-argument', 'Invalid paymentMethod');
  }
  const textError =
    validateOptionalText(data.customerName, FIELD_LIMITS.customerName, 'customerName') ??
    validateOptionalText(data.deliveryAddress, FIELD_LIMITS.deliveryAddress, 'deliveryAddress') ??
    validateOptionalText(data.notes, FIELD_LIMITS.notes, 'notes');
  if (textError) {
    throw new HttpsError('invalid-argument', textError);
  }

  const stallRef = db.collection('vendorStalls').doc(stallId);
  const stallSnap = await stallRef.get();
  if (!stallSnap.exists) {
    throw new HttpsError('not-found', 'Stall not found');
  }
  const stall = stallSnap.data()!;

  const orderRef = db.collection('orders').doc();
  const timestamp = FieldValue.serverTimestamp();

  const resolved: ResolvedItem[] = [];

  await db.runTransaction(async (tx) => {
    // Server-side truth: resolve each product, locking its stock + price
    // inside the transaction so two simultaneous orders cannot oversell.
    for (const item of items) {
      const prodSnap = await tx.get(
        db
          .collection('vendorStalls')
          .doc(stallId)
          .collection('products')
          .doc(item.productId),
      );
      if (!prodSnap.exists) {
        throw new HttpsError('not-found', `Product ${item.productId} not found`);
      }
      const p = prodSnap.data()!;
      if (p.isActive !== true) {
        throw new HttpsError(
          'failed-precondition',
          `Product is not active: ${item.productId}`,
        );
      }
      const stock = typeof p.stockQuantity === 'number' ? p.stockQuantity : 0;
      // Number.isFinite guards NaN/Infinity, which pass <= / > comparisons.
      const quantity =
        typeof item.quantity === 'number' && Number.isFinite(item.quantity)
          ? item.quantity
          : 0;
      if (quantity <= 0 || quantity > stock) {
        throw new HttpsError(
          'out-of-range',
          `Insufficient stock for ${item.productId}`,
        );
      }
      resolved.push({
        productId: item.productId,
        name: p.name ?? '',
        price: p.price ?? 0,
        unit: item.unit ?? p.unit ?? 'kg',
        quantity,
        imageUrl: p.imageUrl ?? '',
      });
      tx.update(prodSnap.ref, { stockQuantity: stock - quantity });
    }

    const itemsTotal = resolved.reduce((sum, i) => sum + i.price * i.quantity, 0);
    // Fees are derived server-side (mirrors FeeConfig) — the client never
    // dictates amounts on the trusted path.
    const isPriority = data.isPriority === true;
    const { deliveryFee, serviceFee, priorityFee } = computeFees(
      data.fulfillmentMethod,
      isPriority,
    );

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
    });

    tx.set(orderRef.collection('statusHistory').doc(), {
      orderId: orderRef.id,
      previousStatus: null,
      newStatus: 'pending',
      changedBy: 'system',
      changedAt: timestamp,
      remarks: null,
    });
  });

  return { orderId: orderRef.id };
  },
);

/**
 * Trusted status transition.
 * - Vendor may advance orders on their own stall.
 * - Customer may cancel their own pending order within the cancel window.
 * Terminal statuses are immutable; the allowed graph is the single source of
 * truth (mirrors Flutter OrderStatus).
 */
export const updateOrderStatus = onCall(
  { enforceAppCheck: APP_CHECK_ENFORCED },
  async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  const data = request.data ?? {};
  const orderId: string | undefined = data.orderId;
  const newStatus: OrderStatus | undefined = data.newStatus;
  if (typeof orderId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing orderId');
  }
  if (typeof newStatus !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing newStatus');
  }

  await applyStatusTransition(uid, {
    orderId,
    newStatus,
    remarks: data.remarks ?? null,
    estimatedReadyTime: data.estimatedReadyTime ?? null,
  });

  return { orderId, status: newStatus };
  },
);

/**
 * Customer-facing cancel — thin wrapper so callers don't need to know
 * status names.
 */
export const cancelOrder = onCall(
  { enforceAppCheck: APP_CHECK_ENFORCED },
  async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  const data = request.data ?? {};
  if (typeof data.orderId !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing orderId');
  }

  await applyStatusTransition(uid, {
    orderId: data.orderId,
    newStatus: 'cancelled',
    remarks: data.reason ?? null,
  });

  return { orderId: data.orderId, status: 'cancelled' };
  },
);

interface TransitionInput {
  orderId: string;
  newStatus: OrderStatus;
  remarks: string | null;
  estimatedReadyTime?: unknown;
}

async function applyStatusTransition(
  uid: string,
  input: TransitionInput,
): Promise<void> {
  if (await isBlocked(uid)) {
    throw new HttpsError('permission-denied', 'Your account is blocked');
  }
  await rateLimit(uid, 'orderStatus', 60);
  const textError = validateOptionalText(
    input.remarks,
    FIELD_LIMITS.remarks,
    'remarks',
  );
  if (textError) {
    throw new HttpsError('invalid-argument', textError);
  }
  const role = await roleOf(uid);
  const orderRef = db.collection('orders').doc(input.orderId);

  // The whole validate+write sequence runs inside ONE transaction: the order
  // is (re)read under lock, so a concurrent cancel-vs-complete cannot both
  // validate against the same stale snapshot and stamp an illegal terminal
  // state (e.g. `paid` on a cancelled order).
  await db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) {
      throw new HttpsError('not-found', 'Order not found');
    }
    const order = orderSnap.data()!;
    const prevStatus = order.status as OrderStatus;

    if (TERMINAL_STATUSES.has(prevStatus)) {
      throw new HttpsError(
        'failed-precondition',
        `Order is already ${prevStatus} and can no longer change`,
      );
    }
    // Same-status re-record (e.g. a vendor updating the estimated ready time on
    // an order they are already preparing) is not a transition — it bypasses the
    // graph but still persists the payload fields, mirroring the old client path.
    const isReRecord = prevStatus === input.newStatus;
    if (!isReRecord && !canTransition(prevStatus, input.newStatus)) {
      throw new HttpsError(
        'failed-precondition',
        `Illegal transition ${prevStatus} -> ${input.newStatus}`,
      );
    }

    const ownerUid = await stallOwnerUid(order.stallId);

    // Vendor path (admins share it — they can unstick any order, e.g. force a
    // stuck preparing order to cancelled — but the transition graph still binds
    // them; terminal states stay immutable).
    if (role === 'vendor' || role === 'stall holder' || role === 'admin') {
      if (role !== 'admin' && ownerUid !== uid) {
        throw new HttpsError('permission-denied', 'Not your stall');
      }
    }
    // Customer cancel path.
    else if (role === 'customer') {
      const isCancel = input.newStatus === 'cancelled';
      const isOwner = order.customerUid === uid;
      const now = Date.now();
      const placedAtMs =
        order.placedAt instanceof Timestamp
          ? order.placedAt.toMillis()
          : Number.NaN;
      const withinWindow = !Number.isNaN(placedAtMs) &&
        now - placedAtMs <= CANCELLATION_WINDOW_MS;
      if (!isOwner) {
        throw new HttpsError('permission-denied', 'Not your order');
      }
      if (!isCancel) {
        throw new HttpsError('permission-denied', 'Customers may only cancel');
      }
      if (!withinWindow) {
        throw new HttpsError(
          'deadline-exceeded',
          'Cancellation window has expired',
        );
      }
    } else {
      throw new HttpsError('permission-denied', 'You do not have permission');
    }

    const update: Record<string, unknown> = {
      status: input.newStatus,
      updatedAt: FieldValue.serverTimestamp(),
    };
    // Only cash orders (COD / cash on pickup) are marked paid at completion by
    // the vendor. Online methods are flipped to 'paid' exclusively by the
    // verified PayMongo webhook (functions/src/payments.ts). Legacy orders
    // without a paymentMethod field are treated as cash.
    if (input.newStatus === 'completed' && isCashPayment(order.paymentMethod ?? 'cod')) {
      update.paymentStatus = 'paid';
    }
    if (
      (input.newStatus === 'cancelled' || input.newStatus === 'rejected') &&
      input.remarks != null
    ) {
      update.cancellationReason = input.remarks;
    }
    // Vendor/admin payload field — customers cancelling must not smuggle it.
    const isPrivileged = role === 'vendor' || role === 'stall holder' || role === 'admin';
    if (isPrivileged && input.estimatedReadyTime != null) {
      update.estimatedReadyTime = input.estimatedReadyTime;
    }
    tx.update(orderRef, update);

    tx.set(orderRef.collection('statusHistory').doc(), {
      orderId: orderRef.id,
      previousStatus: prevStatus,
      newStatus: input.newStatus,
      changedBy: uid,
      changedAt: FieldValue.serverTimestamp(),
      remarks: input.remarks,
    });

    // Stock was deducted transactionally at placement; a cancellation or
    // rejection must return it, or vendors silently lose inventory. Increment
    // is atomic and contention-safe (concurrent cancels + new orders both win).
    if (input.newStatus === 'cancelled' || input.newStatus === 'rejected') {
      const items = Array.isArray(order.items)
        ? (order.items as Array<{ productId?: string; quantity?: number }>)
        : [];
      for (const item of items) {
        if (
          typeof item.productId !== 'string' ||
          !(typeof item.quantity === 'number' && Number.isFinite(item.quantity)) ||
          item.quantity <= 0
        ) {
          continue; // malformed legacy line item — skip rather than block the cancel
        }
        const productRef = db
          .collection('vendorStalls')
          .doc(order.stallId as string)
          .collection('products')
          .doc(item.productId);
        tx.update(productRef, {
          stockQuantity: FieldValue.increment(item.quantity),
        });
      }
    }
  });
}