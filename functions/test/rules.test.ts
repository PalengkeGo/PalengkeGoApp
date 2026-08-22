/**
 * Firestore security-rules tests (Phase 3 acceptance).
 *
 *   npm run test:rules   (spins up firestore+auth emulators, runs jest)
 *
 * Coverage:
 *   - unauthenticated access is denied except public catalog reads
 *   - a customer may only touch their own data; order creation is
 *     trusted-path only (denied for all clients)
 *   - a vendor may only maintain their own stall/products
 *   - rating writes require an order completed AND owned by the reviewer
 *   - roles/account flags cannot be self-escalated
 */
import * as fs from 'fs';
import * as path from 'path';
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { assertSucceeds } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-palengkego';
const CUSTOMER_A = 'customer-a';
const CUSTOMER_B = 'customer-b';
const VENDOR = 'vendor-v';
const STALL_A = VENDOR; // stallId == owner uid
const STALL_B = 'stall-other';

// @firebase/rules-unit-testing v3 expects the rules SOURCE, not a file path.
const FIRESTORE_RULES = fs.readFileSync(
  path.resolve(__dirname, '../../firestore.rules'),
  'utf8',
);

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: FIRESTORE_RULES,
    },
  });

  // Seed the baseline world with rules bypassed.
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', CUSTOMER_A), {
      uid: CUSTOMER_A,
      role: 'customer',
      isBlocked: false,
      isVerified: false,
    });
    await setDoc(doc(db, 'users', CUSTOMER_B), {
      uid: CUSTOMER_B,
      role: 'customer',
      isBlocked: false,
      isVerified: false,
    });
    await setDoc(doc(db, 'users', VENDOR), {
      uid: VENDOR,
      role: 'vendor',
      isBlocked: false,
      isVerified: false,
    });
    await setDoc(doc(db, 'vendorStalls', STALL_A), {
      ownerUid: VENDOR,
      name: 'Stall A',
      category: 'Vegetables',
      isOpen: true,
      isKYCApproved: false,
    });
    await setDoc(doc(db, 'vendorStalls', STALL_B), {
      ownerUid: 'someone-else',
      name: 'Stall B',
    });
    await setDoc(doc(db, 'vendorStalls', STALL_A, 'products', 'p1'), {
      vendorId: STALL_A,
      name: 'Kangkong',
      price: 15,
      stockQuantity: 10,
      isActive: true,
      unit: 'kg',
    });
    await setDoc(doc(db, 'customerProfiles', CUSTOMER_A), {
      uid: CUSTOMER_A,
      displayName: 'Customer A',
    });
    await setDoc(doc(db, 'customerProfiles', CUSTOMER_B), {
      uid: CUSTOMER_B,
      displayName: 'Customer B',
    });
    // Completed order owned by Customer A at Stall A (for the rating test).
    await setDoc(doc(db, 'orders', 'order-completed'), {
      customerUid: CUSTOMER_A,
      stallId: STALL_A,
      status: 'completed',
      paymentStatus: 'paid',
      paymentMethod: 'cod',
      items: [{ productId: 'p1', productName: 'Kangkong', quantity: 2, unitPrice: 15, unit: 'kg', image: '' }],
      placedAt: new Date(),
    });
    // Gcash order (online payment — only the webhook may mark it paid).
    await setDoc(doc(db, 'orders', 'order-gcash-pending'), {
      customerUid: CUSTOMER_A,
      stallId: STALL_A,
      status: 'pending',
      paymentStatus: 'pending',
      paymentMethod: 'gcash',
      items: [{ productId: 'p1', productName: 'Kangkong', quantity: 1, unitPrice: 15, unit: 'kg' }],
      placedAt: new Date(),
    });
    // COD order that is still pending (the legitimate paid-on-completion path).
    await setDoc(doc(db, 'orders', 'order-cod-pending'), {
      customerUid: CUSTOMER_A,
      stallId: STALL_A,
      status: 'pending',
      paymentStatus: 'pending',
      paymentMethod: 'cod',
      items: [{ productId: 'p1', productName: 'Kangkong', quantity: 1, unitPrice: 15, unit: 'kg' }],
      placedAt: new Date(),
    });
  });
});

afterAll(async () => {
  await env.cleanup();
});

const denied = (promise: Promise<unknown>) =>
  expect(promise).rejects.toMatchObject({ code: 'permission-denied' });

// Shape-agnostic: compat snapshots expose exists as a method, modular as bool.
const exists = (snap: { exists: boolean | (() => boolean) }): boolean =>
  typeof snap.exists === 'function' ? (snap.exists as () => boolean)() : snap.exists;

describe('unauthenticated access', () => {
  test('cannot read an order', async () => {
    const db = env.unauthenticatedContext().firestore();
    await denied(getDoc(doc(db, 'orders', 'order-completed')));
  });
  test('cannot read a customer profile', async () => {
    const db = env.unauthenticatedContext().firestore();
    await denied(getDoc(doc(db, 'customerProfiles', CUSTOMER_A)));
  });
  test('may read the public product catalog', async () => {
    const db = env.unauthenticatedContext().firestore();
    const snap = await getDoc(
      doc(db, 'vendorStalls', STALL_A, 'products', 'p1'),
    );
    expect(exists(snap)).toBe(true);
  });
});

describe('customer isolation', () => {
  const auth = () => env.authenticatedContext(CUSTOMER_A).firestore();

  test('can read own profile only', async () => {
    const snap = await getDoc(doc(auth(), 'customerProfiles', CUSTOMER_A));
    expect(exists(snap)).toBe(true);
    await denied(getDoc(doc(auth(), 'customerProfiles', CUSTOMER_B)));
  });

  test('cannot create orders directly — trusted path only', async () => {
    // Even a perfectly-formed order must be denied: prices, fees and stock
    // are recomputed server-side by the placeOrder callable. A client-side
    // create with attacker-chosen unitPrice would poison revenue math.
    const ref = doc(auth(), 'orders', 'order-customer-a');
    await denied(
      setDoc(ref, {
        customerUid: CUSTOMER_A,
        stallId: STALL_A,
        status: 'pending',
        paymentStatus: 'pending',
        paymentMethod: 'cod',
        deliveryFee: 49,
        serviceFee: 15,
        priorityFee: 0,
        items: [{ productId: 'p1', productName: 'Kangkong', quantity: 1, unitPrice: 15, unit: 'kg' }],
      }),
    );
  });

  test('cannot place an order with negative fees', async () => {
    await denied(
      setDoc(doc(auth(), 'orders', 'order-negative-fee'), {
        customerUid: CUSTOMER_A,
        stallId: STALL_A,
        status: 'pending',
        paymentStatus: 'pending',
        paymentMethod: 'cod',
        deliveryFee: -49, // price manipulation
        serviceFee: 15,
        priorityFee: 0,
        items: [{ productId: 'p1', productName: 'Kangkong', quantity: 1, unitPrice: 15, unit: 'kg' }],
      }),
    );
  });

  test('cannot place an order with an unknown payment method', async () => {
    await denied(
      setDoc(doc(auth(), 'orders', 'order-bad-method'), {
        customerUid: CUSTOMER_A,
        stallId: STALL_A,
        status: 'pending',
        paymentStatus: 'pending',
        paymentMethod: 'bitcoin',
        deliveryFee: 49,
        serviceFee: 15,
        priorityFee: 0,
        items: [{ productId: 'p1', productName: 'Kangkong', quantity: 1, unitPrice: 15, unit: 'kg' }],
      }),
    );
  });

  test('cannot place an order with an oversized note', async () => {
    await denied(
      setDoc(doc(auth(), 'orders', 'order-long-note'), {
        customerUid: CUSTOMER_A,
        stallId: STALL_A,
        status: 'pending',
        paymentStatus: 'pending',
        paymentMethod: 'cod',
        notes: 'x'.repeat(501),
        deliveryFee: 49,
        serviceFee: 15,
        priorityFee: 0,
        items: [{ productId: 'p1', productName: 'Kangkong', quantity: 1, unitPrice: 15, unit: 'kg' }],
      }),
    );
  });

  test('cannot place an order under another user', async () => {
    await denied(
      setDoc(doc(auth(), 'orders', 'order-spoofed'), {
        customerUid: CUSTOMER_B, // spoofing
        stallId: STALL_A,
        status: 'pending',
        paymentStatus: 'pending',
        deliveryFee: 49,
        serviceFee: 15,
        priorityFee: 0,
        items: [],
      }),
    );
  });

  test('cannot create a non-pending order', async () => {
    await denied(
      setDoc(doc(auth(), 'orders', 'order-completed-direct'), {
        customerUid: CUSTOMER_A,
        stallId: STALL_A,
        status: 'completed',
        paymentStatus: 'pending',
        paymentMethod: 'cod',
        items: [],
      }),
    );
  });

  test('cannot modify a vendor catalog', async () => {
    await denied(
      updateDoc(doc(auth(), 'vendorStalls', STALL_A, 'products', 'p1'), {
        price: 1,
      }),
    );
  });

  test('cannot delete a product from a catalog they do not own', async () => {
    // VENDOR owns STALL_A; STALL_B belongs to someone-else. Seed a product
    // there with rules bypassed, then attempt the delete as VENDOR.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'vendorStalls', STALL_B, 'products', 'p-other'),
        { vendorId: STALL_B, name: 'Not Yours', price: 10, stockQuantity: 1 },
      );
    });
    const vendor = env.authenticatedContext(VENDOR).firestore();
    await denied(
      deleteDoc(doc(vendor, 'vendorStalls', STALL_B, 'products', 'p-other')),
    );
  });
});

describe('vendor ownership', () => {
  const auth = () => env.authenticatedContext(VENDOR).firestore();

  test('may update their own stall', async () => {
    await expect(
      updateDoc(doc(auth(), 'vendorStalls', STALL_A), { isOpen: false }),
    ).resolves.toBeUndefined();
  });

  test('may not transfer stall ownership', async () => {
    await denied(
      updateDoc(doc(auth(), 'vendorStalls', STALL_A), { ownerUid: 'hacked' }),
    );
  });

  test('may not touch another stall', async () => {
    await denied(
      updateDoc(doc(auth(), 'vendorStalls', STALL_B), { isOpen: true }),
    );
  });

  test('may maintain their own products', async () => {
    await expect(
      updateDoc(doc(auth(), 'vendorStalls', STALL_A, 'products', 'p1'), {
        price: 18,
      }),
    ).resolves.toBeUndefined();
  });

  test('may not touch another stall products', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'vendorStalls', STALL_B, 'products', 'pB'),
        { vendorId: STALL_B, name: 'B product' },
      );
    });
    await denied(
      updateDoc(doc(auth(), 'vendorStalls', STALL_B, 'products', 'pB'), {
        price: 1,
      }),
    );
  });

  test('may read own salesSummary but never write it', async () => {
    const ref = doc(auth(), 'salesSummary', STALL_A, 'daily', '2026-08-07');
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'salesSummary', STALL_A, 'daily', '2026-08-07'),
        { date: '2026-08-07', totalRevenue: 0, orderCount: 0 },
      );
    });
    await denied(
      setDoc(ref, { date: '2026-08-07', totalRevenue: 999, orderCount: 99 }),
    );
  });
});

describe('ratings', () => {
  // Deterministic doc id contract: {orderId}_{customerUid}
  const ratingId = (orderId: string, uid = CUSTOMER_A) => `${orderId}_${uid}`;

  test('customer cannot rate an order they do not own', async () => {
    const db = env.authenticatedContext(CUSTOMER_B).firestore();
    await denied(
      setDoc(doc(db, 'ratings', ratingId('order-completed', CUSTOMER_B)), {
        vendorId: STALL_A,
        customerId: CUSTOMER_B,
        customerName: 'B',
        rating: 5,
        orderId: 'order-completed', // owned by CUSTOMER_A
        reviewType: 'vendor',
      }),
    );
  });

  test('customer cannot rate an order that is not completed', async () => {
    const db = env.authenticatedContext(CUSTOMER_A).firestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'orders', 'order-pending-for-rating'),
        {
          customerUid: CUSTOMER_A,
          stallId: STALL_A,
          status: 'pending',
          paymentStatus: 'pending',
          items: [],
        },
      );
    });
    await denied(
      setDoc(doc(db, 'ratings', ratingId('order-pending-for-rating')), {
        vendorId: STALL_A,
        customerId: CUSTOMER_A,
        rating: 5,
        orderId: 'order-pending-for-rating',
      }),
    );
  });

  test('customer may rate their own completed order (deterministic id)', async () => {
    const db = env.authenticatedContext(CUSTOMER_A).firestore();
    await expect(
      setDoc(doc(db, 'ratings', ratingId('order-completed')), {
        vendorId: STALL_A,
        customerId: CUSTOMER_A,
        customerName: 'A',
        rating: 4,
        comment: 'Masarap!',
        orderId: 'order-completed',
        reviewType: 'vendor',
      }),
    ).resolves.toBeUndefined();
  });

  test('customer cannot attribute a review to a different vendor', async () => {
    const db = env.authenticatedContext(CUSTOMER_A).firestore();
    await denied(
      setDoc(doc(db, 'ratings', ratingId('order-completed')), {
        vendorId: STALL_B, // forged — the completed order is at STALL_A
        customerId: CUSTOMER_A,
        rating: 1,
        orderId: 'order-completed',
        reviewType: 'vendor',
      }),
    );
  });

  test('customer cannot use a non-deterministic doc id (unlimited duplicates)', async () => {
    const db = env.authenticatedContext(CUSTOMER_A).firestore();
    await denied(
      setDoc(doc(db, 'ratings', 'spam-1'), {
        vendorId: STALL_A,
        customerId: CUSTOMER_A,
        rating: 5,
        orderId: 'order-completed', // otherwise fully legitimate
        reviewType: 'vendor',
      }),
    );
  });

  test('a review cannot be rewritten after the fact', async () => {
    const db = env.authenticatedContext(CUSTOMER_A).firestore();
    await denied(
      updateDoc(doc(db, 'ratings', ratingId('order-completed')), {
        rating: 1,
      }),
    );
  });
});

describe('account integrity', () => {
  test('a user cannot self-register as vendor', async () => {
    const db = env.authenticatedContext(CUSTOMER_A).firestore();
    await denied(
      setDoc(doc(db, 'users', CUSTOMER_A), { role: 'vendor' }),
    );
  });

  test('a user cannot escalate their own role', async () => {
    const db = env.authenticatedContext(CUSTOMER_A).firestore();
    await denied(
      updateDoc(doc(db, 'users', CUSTOMER_A), { role: 'admin' }),
    );
  });
});

describe('order audit log + payment integrity', () => {
  const customer = () => env.authenticatedContext(CUSTOMER_A).firestore();
  const vendor = () => env.authenticatedContext(VENDOR).firestore();

  test('a client cannot write a statusHistory entry (even stamped as itself)', async () => {
    await denied(
      setDoc(
        doc(customer(), 'orders', 'order-cod-pending', 'statusHistory', 'h1'),
        {
          orderId: 'order-cod-pending',
          previousStatus: 'pending',
          newStatus: 'cancelled',
          changedBy: CUSTOMER_A,
          changedAt: new Date(),
        },
      ),
    );
  });

  test('a client cannot forge a system audit entry', async () => {
    await denied(
      setDoc(
        doc(customer(), 'orders', 'order-cod-pending', 'statusHistory', 'h2'),
        {
          orderId: 'order-cod-pending',
          previousStatus: 'pending',
          newStatus: 'cancelled',
          changedBy: 'system',
          changedAt: new Date(),
        },
      ),
    );
  });

  test('the owning customer can read their order history', async () => {
    // History docs carry no ownership fields — authorization goes through
    // the parent order (seeded with customerUid: CUSTOMER_A).
    await assertSucceeds(
      getDoc(doc(customer(), 'orders', 'order-cod-pending', 'statusHistory', 'any')),
    );
  });

  test('a customer cannot read another customer order history', async () => {
    const other = env.authenticatedContext(CUSTOMER_B).firestore();
    await denied(
      getDoc(doc(other, 'orders', 'order-cod-pending', 'statusHistory', 'any')),
    );
  });

  test('a vendor cannot mark an online-paid order as paid at completion', async () => {
    await denied(
      updateDoc(doc(vendor(), 'orders', 'order-gcash-pending'), {
        status: 'completed',
        paymentStatus: 'paid',
      }),
    );
  });

  test('a vendor may complete and mark a COD order paid', async () => {
    await expect(
      updateDoc(doc(vendor(), 'orders', 'order-cod-pending'), {
        status: 'completed',
        paymentStatus: 'paid',
      }),
    ).resolves.toBeUndefined();
  });
});