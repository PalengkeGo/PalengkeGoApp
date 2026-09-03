/**
 * Firestore security-rules tests (Phase 3 acceptance).
 *
 *   npm run test:rules   (spins up firestore+auth emulators, runs jest)
 *
 * Coverage:
 *   - unauthenticated access is denied except public catalog reads
 *   - a customer may only touch their own data; order creation AND updates
 *     are trusted-path only (denied for all clients, audit H3)
 *   - a vendor may only maintain their own stall/products; privileged stall
 *     fields (KYC, license, rating, stall number) are callable-only (audit H1)
 *   - product price/stock must be non-negative on create AND update (audit M3)
 *   - ratings are trusted-path only — even a perfect review is denied (audit M2)
 *   - KYC/license submissions: own identity only, no pre-stamped review
 *     fields, blocked accounts denied (audit H4/M4)
 *   - salesSummary readable by the owning vendor at the real top-level path,
 *     never writable (audit H2)
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
    // Positive read assertion (audit 2026-08-23 H2): the earlier version of
    // this test only asserted the write denial, which is how the missing
    // read grant survived five audits. The read must happen at the SAME
    // top-level path the rollup writes and the earnings screen reads.
    const snap = await getDoc(ref);
    expect(exists(snap)).toBe(true);
    // A non-owner cannot read the rollup.
    await denied(
      getDoc(
        doc(
          env.authenticatedContext(CUSTOMER_A).firestore(),
          'salesSummary', STALL_A, 'daily', '2026-08-07',
        ),
      ),
    );
    await denied(
      setDoc(ref, { date: '2026-08-07', totalRevenue: 999, orderCount: 99 }),
    );
  });

  test('may not self-approve KYC or grant themselves a license', async () => {
    // Audit 2026-08-23 H1: privileged stall fields are callable-only.
    await denied(
      updateDoc(doc(auth(), 'vendorStalls', STALL_A), {
        isKYCApproved: true,
        kycStatus: 'approved',
      }),
    );
    await denied(
      updateDoc(doc(auth(), 'vendorStalls', STALL_A), {
        licenseStatus: 'active',
      }),
    );
  });

  test('may not inflate their own rating aggregate', async () => {
    await denied(
      updateDoc(doc(auth(), 'vendorStalls', STALL_A), {
        averageRating: 5,
        totalRatings: 9999,
      }),
    );
  });

  test('may not claim an admin-assigned stall number', async () => {
    await denied(
      updateDoc(doc(auth(), 'vendorStalls', STALL_A), {
        stallNumber: 'A-1',
        section: 'Wet Section',
      }),
    );
  });

  test('may not create a product with a negative price or stock', async () => {
    // Audit 2026-08-23 M3: negative prices would flow into server-side
    // order totals and poison revenue math.
    await denied(
      setDoc(doc(auth(), 'vendorStalls', STALL_A, 'products', 'p-neg-price'), {
        vendorId: STALL_A,
        name: 'Loss leader',
        price: -50,
        stockQuantity: 10,
      }),
    );
    await denied(
      setDoc(doc(auth(), 'vendorStalls', STALL_A, 'products', 'p-neg-stock'), {
        vendorId: STALL_A,
        name: 'Ghost stock',
        price: 10,
        stockQuantity: -1,
      }),
    );
  });

  test('may create a valid product', async () => {
    await expect(
      setDoc(doc(auth(), 'vendorStalls', STALL_A, 'products', 'p-ok'), {
        vendorId: STALL_A,
        name: 'Malunggay',
        price: 20,
        stockQuantity: 5,
        isActive: true,
        unit: 'bundle',
      }),
    ).resolves.toBeUndefined();
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

  test('even a perfect review must go through the trusted path', async () => {
    // Audit 2026-08-23 M2: ratings creation is trusted-path only. A direct
    // client write would create the review doc WITHOUT the addReview
    // callable's same-transaction aggregate recompute (rating drift), so
    // even a perfectly-formed, deterministic-id review is denied.
    const db = env.authenticatedContext(CUSTOMER_A).firestore();
    await denied(
      setDoc(doc(db, 'ratings', ratingId('order-completed')), {
        vendorId: STALL_A,
        customerId: CUSTOMER_A,
        customerName: 'A',
        rating: 4,
        comment: 'Masarap!',
        orderId: 'order-completed',
        reviewType: 'vendor',
      }),
    );
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

describe('admin portal collections', () => {
  test('a customer cannot publish announcements', async () => {
    const db = env.authenticatedContext(CUSTOMER_A).firestore();
    await denied(
      setDoc(doc(db, 'systemAnnouncements', 'ann-x'), {
        title: 'Fake notice',
        body: 'Not an admin',
        targetAudience: 'all',
      }),
    );
  });

  test('an admin can publish announcements', async () => {
    const admin = env.authenticatedContext('admin-x').firestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', 'admin-x'), {
        uid: 'admin-x',
        role: 'admin',
        isBlocked: false,
      });
    });
    await expect(
      setDoc(doc(admin, 'systemAnnouncements', 'ann-ok'), {
        title: 'Market holiday',
        body: 'Closed Monday',
        targetAudience: 'all',
      }),
    ).resolves.toBeUndefined();
  });

  test('the admin audit log is client-unwritable, admin-readable', async () => {
    const admin = env.authenticatedContext('admin-x').firestore();
    await denied(
      setDoc(doc(admin, 'adminActions', 'act-1'), {
        action: 'kyc.approved',
        byUid: 'admin-x',
      }),
    );
    await assertSucceeds(getDoc(doc(admin, 'adminActions', 'act-any')));
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

  test('a vendor cannot update an order at all — trusted path only', async () => {
    // Audit 2026-08-23 H3: order updates flow exclusively through the
    // updateOrderStatus/cancelOrder callables (state graph, audit log,
    // restock). The old rules path let a raw-SDK vendor jump the state
    // machine — even the previously-legitimate COD completion is now denied
    // at the rules layer and must go through the callable.
    await denied(
      updateDoc(doc(vendor(), 'orders', 'order-cod-pending'), {
        status: 'completed',
        paymentStatus: 'paid',
      }),
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

  test('a customer cannot cancel their own order directly — trusted path only', async () => {
    // The cancelOrder callable enforces the window + restocks; a direct
    // rules write did neither.
    await denied(
      updateDoc(doc(customer(), 'orders', 'order-cod-pending'), {
        status: 'cancelled',
      }),
    );
  });
});

describe('KYC onboarding (audit 2026-08-23 H4)', () => {
  test('a customer may submit their own KYC application', async () => {
    const db = env.authenticatedContext(CUSTOMER_A).firestore();
    await expect(
      setDoc(doc(db, 'kycSubmissions', 'kyc-1'), {
        stallHolderId: CUSTOMER_A,
        status: 'pending',
        mayorPermitUrl: 'https://example.com/permit.jpg',
        submittedAt: new Date(),
      }),
    ).resolves.toBeUndefined();
  });

  test('a customer cannot submit under another identity', async () => {
    const db = env.authenticatedContext(CUSTOMER_A).firestore();
    await denied(
      setDoc(doc(db, 'kycSubmissions', 'kyc-2'), {
        stallHolderId: CUSTOMER_B,
        status: 'pending',
      }),
    );
  });

  test('a customer cannot pre-stamp the review outcome', async () => {
    const db = env.authenticatedContext(CUSTOMER_A).firestore();
    await denied(
      setDoc(doc(db, 'kycSubmissions', 'kyc-3'), {
        stallHolderId: CUSTOMER_A,
        status: 'approved',
      }),
    );
    await denied(
      setDoc(doc(db, 'kycSubmissions', 'kyc-4'), {
        stallHolderId: CUSTOMER_A,
        status: 'pending',
        reviewedBy: 'admin-x',
      }),
    );
  });
});

describe('license renewals (audit 2026-08-23 H4)', () => {
  test('a vendor may file their own renewal request', async () => {
    const db = env.authenticatedContext(VENDOR).firestore();
    await expect(
      setDoc(doc(db, 'licenseRenewals', 'renewal-1'), {
        stallId: STALL_A,
        vendorUid: VENDOR,
        status: 'pending',
        permitUrl: 'https://example.com/permit.jpg',
        submittedAt: new Date(),
      }),
    ).resolves.toBeUndefined();
  });

  test('a customer cannot file a renewal (vendor role required)', async () => {
    const db = env.authenticatedContext(CUSTOMER_A).firestore();
    await denied(
      setDoc(doc(db, 'licenseRenewals', 'renewal-2'), {
        stallId: STALL_A,
        vendorUid: CUSTOMER_A,
        status: 'pending',
      }),
    );
  });

  test('a vendor cannot pre-stamp the review outcome', async () => {
    const db = env.authenticatedContext(VENDOR).firestore();
    await denied(
      setDoc(doc(db, 'licenseRenewals', 'renewal-3'), {
        stallId: STALL_A,
        vendorUid: VENDOR,
        status: 'approved',
      }),
    );
    await denied(
      setDoc(doc(db, 'licenseRenewals', 'renewal-4'), {
        stallId: STALL_A,
        vendorUid: VENDOR,
        status: 'pending',
        reviewedAt: new Date(),
      }),
    );
  });
});

describe('blocked accounts (audit 2026-08-23 M4)', () => {
  const BLOCKED_VENDOR = 'vendor-blocked';

  beforeAll(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users', BLOCKED_VENDOR), {
        uid: BLOCKED_VENDOR,
        role: 'vendor',
        isBlocked: true,
        isVerified: false,
      });
      await setDoc(doc(db, 'vendorStalls', BLOCKED_VENDOR), {
        ownerUid: BLOCKED_VENDOR,
        name: 'Blocked Stall',
      });
      await setDoc(
        doc(db, 'vendorStalls', BLOCKED_VENDOR, 'products', 'pb1'),
        { vendorId: BLOCKED_VENDOR, name: 'Item', price: 10, stockQuantity: 1 },
      );
    });
  });

  const auth = () => env.authenticatedContext(BLOCKED_VENDOR).firestore();

  test('a blocked vendor cannot update their stall', async () => {
    await denied(
      updateDoc(doc(auth(), 'vendorStalls', BLOCKED_VENDOR), { isOpen: false }),
    );
  });

  test('a blocked vendor cannot maintain products', async () => {
    await denied(
      updateDoc(doc(auth(), 'vendorStalls', BLOCKED_VENDOR, 'products', 'pb1'), {
        price: 12,
        stockQuantity: 1,
      }),
    );
    await denied(
      setDoc(doc(auth(), 'vendorStalls', BLOCKED_VENDOR, 'products', 'pb2'), {
        vendorId: BLOCKED_VENDOR,
        name: 'New item',
        price: 5,
        stockQuantity: 2,
      }),
    );
  });

  test('a blocked customer cannot submit KYC', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', 'customer-blocked'), {
        uid: 'customer-blocked',
        role: 'customer',
        isBlocked: true,
      });
    });
    const db = env.authenticatedContext('customer-blocked').firestore();
    await denied(
      setDoc(doc(db, 'kycSubmissions', 'kyc-blocked'), {
        stallHolderId: 'customer-blocked',
        status: 'pending',
      }),
    );
  });
});