/**
 * END-TO-END money-path test: placeOrder → createPaymentIntent → webhook.
 *
 * Runs against the REAL Firebase emulators (firestore + auth + functions)
 * with a stub PayMongo HTTP server standing in for the external API — the
 * full trusted-backend money path executes as deployed code, not mocks.
 *
 * Only runs when PAYMENTS_E2E is set (skipped in plain `npm test`):
 *
 *   npm run test:payments-e2e
 *     → builds functions, starts emulators with PAYMONGO_* env pointing at
 *       the stub, then runs this suite.
 */
import { createHmac } from 'crypto';
import * as http from 'http';
import { initializeApp, deleteApp } from 'firebase/app';
import {
  getAuth,
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import { initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';

const RUN = process.env.PAYMENTS_E2E === '1';
const d = RUN ? describe : describe.skip;

const PROJECT = 'demo-palengkegodb';
const REGION = 'asia-southeast1';
const FN_BASE = `http://127.0.0.1:5001/${PROJECT}/${REGION}`;
const AUTH_BASE = 'http://127.0.0.1:9099';
const WEBHOOK_SECRET = process.env.PAYMONGO_WEBHOOK_SECRET || 'whsec_e2e_stub';
const STUB_PORT = 9777;

let env: RulesTestEnvironment;
let stub: http.Server;
const stubRequests: Array<{ method?: string; url?: string; body?: any }> = [];
let stubIntentCounter = 0;

function startStub(): Promise<void> {
  stub = http.createServer((req, res) => {
    let raw = '';
    req.on('data', (c) => (raw += c));
    req.on('end', () => {
      const body = raw ? JSON.parse(raw) : null;
      stubRequests.push({ method: req.method, url: req.url, body });
      if (req.url?.includes('/payment_intents')) {
        stubIntentCounter += 1;
        const id = `int_e2e_${stubIntentCounter}`;
        res.setHeader('Content-Type', 'application/json');
        res.end(
          JSON.stringify({
            data: { id, attributes: { client_key: `ck_${id}`, status: 'awaiting_payment_method' } },
          }),
        );
      } else {
        res.statusCode = 404;
        res.end('{}');
      }
    });
  });
  return new Promise((resolve) => stub.listen(STUB_PORT, '127.0.0.1', resolve));
}

let fbApp: ReturnType<typeof initializeApp> | undefined;

async function signUp(email: string): Promise<{ uid: string; idToken: string }> {
  if (!fbApp) {
    fbApp = initializeApp({ projectId: PROJECT, apiKey: 'fake', authDomain: 'e2e.local' });
    connectAuthEmulator(getAuth(fbApp), 'http://127.0.0.1:9099', { disableWarnings: true });
  }
  const cred = await createUserWithEmailAndPassword(getAuth(fbApp), email, 'e2ePassw0rd!');
  const idToken = await cred.user.getIdToken();
  await signOut(getAuth(fbApp)); // fresh auth per callable call is unnecessary; token stays valid
  return { uid: cred.user.uid, idToken };
}

async function callCallable(name: string, idToken: string, data: unknown) {
  const res = await fetch(`${FN_BASE}/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify({ data }),
  });
  const payload: any = await res.json().catch(() => null);
  if (res.status !== 200) console.log(name, '→', res.status, JSON.stringify(payload));
  return { status: res.status, payload };
}

async function postWebhook(event: any, sign: boolean) {
  const body = JSON.stringify(event);
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (sign) {
    const t = Math.floor(Date.now() / 1000);
    const sig = createHmac('sha256', WEBHOOK_SECRET).update(`${t}.${body}`).digest('hex');
    headers['Paymongo-Signature'] = `t=${t},te=${sig},li=`;
  }
  const res = await fetch(`${FN_BASE}/paymongoWebhook`, { method: 'POST', headers, body });
  return { status: res.status, text: await res.text() };
}

const paidEvent = (intentId: string) => ({
  data: { attributes: { type: 'payment.paid', data: { id: `pay_${intentId}`, attributes: { payment_intent_id: intentId, status: 'paid' } } } },
});
const failedEvent = (intentId: string) => ({
  data: { attributes: { type: 'payment.failed', data: { id: `pay_${intentId}`, attributes: { payment_intent_id: intentId, status: 'failed' } } } },
});

async function seedCustomerWithOrderReady(): Promise<{ uid: string; idToken: string }> {
  const { uid, idToken } = await signUp(`e2e-${Date.now()}@test.local`);
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.collection('users').doc(uid).set({ uid, role: 'customer', isBlocked: false });
    await db.collection('vendorStalls').doc('stall_e2e').set({
      ownerUid: 'vendor-e2e',
      name: 'E2E Stall',
      isOpen: true,
    });
    await db.collection('vendorStalls').doc('stall_e2e').collection('products').doc('p1').set({
      vendorId: 'stall_e2e',
      name: 'Kangkong',
      price: 15.5,
      stockQuantity: 10,
      isActive: true,
      unit: 'kg',
    });
  });
  return { uid, idToken };
}

async function placeOrder(idToken: string): Promise<string> {
  const placed = await callCallable('placeOrder', idToken, {
    stallId: 'stall_e2e',
    items: [{ productId: 'p1', quantity: 1, unit: 'kg' }],
    fulfillmentMethod: 'delivery',
    paymentMethod: 'gcash',
    customerName: 'E2E Customer',
  });
  expect(placed.status).toBe(200);
  expect(placed.payload?.result?.orderId).toBeTruthy();
  return placed.payload.result.orderId as string;
}

async function orderDoc(orderId: string): Promise<any> {
  // withSecurityRulesDisabled does not propagate the callback's return
  // value — capture via side effect.
  let out: any;
  await env.withSecurityRulesDisabled(async (ctx) => {
    out = (await ctx.firestore().collection('orders').doc(orderId).get()).data();
  });
  return out;
}

d('payments e2e: placeOrder → createPaymentIntent → webhook', () => {
  jest.setTimeout(120_000);

  beforeAll(async () => {
    await startStub();
    env = await initializeTestEnvironment({
      projectId: PROJECT,
      firestore: { host: '127.0.0.1', port: 8080 },
      auth: { host: '127.0.0.1', port: 9099 },
    });
  });

  afterAll(async () => {
    await env?.cleanup();
    await new Promise<void>((resolve) => stub?.close(() => resolve()));
    if (fbApp) await deleteApp(fbApp);
  });

  test('unsigned webhook is rejected', async () => {
    const { status } = await postWebhook(paidEvent('int_none'), false);
    expect(status).toBe(401);
  });

  test('order → intent → signed paid webhook flips the order', async () => {
    const { idToken } = await seedCustomerWithOrderReady();
    const orderId = await placeOrder(idToken);

    // Order placed: pending, stock deducted.
    let order = await orderDoc(orderId);
    expect(order.status).toBe('pending');
    expect(order.paymentStatus).toBe('pending');
    expect(order.items[0].unitPrice).toBe(15.5);

    // Intent created via the trusted callable; stub received the
    // server-computed amount (15.5 + 49 delivery + 15 service = 79.50 → 7950).
    const intent = await callCallable('createPaymentIntent', idToken, {
      orderId,
      paymentMethod: 'gcash',
    });
    expect(intent.status).toBe(200);
    expect(intent.payload?.result?.intentId).toBe('int_e2e_1');
    expect(intent.payload?.result?.amount).toBe(7950);

    order = await orderDoc(orderId);
    expect(order.paymentStatus).toBe('processing');
    expect(order.paymentIntentId).toBe('int_e2e_1');
    expect(stubRequests.some((r) => r.url === '/v1/payment_intents')).toBe(true);

    // Signed payment.paid webhook → paid, idempotently.
    const hook = await postWebhook(paidEvent('int_e2e_1'), true);
    expect(hook.status).toBe(200);
    order = await orderDoc(orderId);
    expect(order.paymentStatus).toBe('paid');
    expect(order.paymentId).toBe('pay_int_e2e_1');

    const again = await postWebhook(paidEvent('int_e2e_1'), true);
    expect(again.status).toBe(200);
    expect((await orderDoc(orderId)).paymentStatus).toBe('paid');

    // A late/duplicate failed event must NOT downgrade a paid order.
    const failed = await postWebhook(failedEvent('int_e2e_1'), true);
    expect(failed.status).toBe(200);
    expect((await orderDoc(orderId)).paymentStatus).toBe('paid');
  });

  test('signed failed webhook marks an unpaid order failed', async () => {
    const { idToken } = await seedCustomerWithOrderReady();
    const orderId = await placeOrder(idToken);
    const intent = await callCallable('createPaymentIntent', idToken, {
      orderId,
      paymentMethod: 'gcash',
    });
    expect(intent.status).toBe(200);
    const intentId = intent.payload.result.intentId as string;

    const hook = await postWebhook(failedEvent(intentId), true);
    expect(hook.status).toBe(200);
    const order = await orderDoc(orderId);
    expect(order.paymentStatus).toBe('failed');
  });
});
