/**
 * Backfill: create `stallCatalog/{stallId}` from every existing
 * `vendorStalls/{stallId}` doc (audit 2026-09-13 M2 — the field split).
 *
 * Idempotent: re-running upserts (merge) and never resets an aggregate that
 * addReview has already written.
 *
 * Run:
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json \
 *     node functions/scripts/backfill-stall-catalog.js
 *
 * The PUBLIC field set mirrors firestore.rules /stallCatalog — admin-assigned
 * allocation (stallNumber/floorNumber/section), ownerUid and KYC/license
 * detail deliberately stay private on vendorStalls.
 */

const admin = require('firebase-admin');

admin.initializeApp(); // uses GOOGLE_APPLICATION_CREDENTIALS / ADC

const db = admin.firestore();

// Public storefront fields copied to stallCatalog.
const CATALOG_FIELDS = [
  'name',
  'description',
  'category',
  'location',
  'bannerImage',
  'avatarImage',
  'thumbnailImage',
  'isOpen',
  'schedule',
  'deliverySettings',
  'tags',
  'isKYCApproved',
];

async function main() {
  const stalls = await db.collection('vendorStalls').get();
  if (stalls.empty) {
    console.log('No vendorStalls docs found — nothing to backfill.');
    return;
  }

  let batch = db.batch();
  let ops = 0;
  let total = 0;

  for (const stall of stalls.docs) {
    const data = stall.data();
    const catalog = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    for (const field of CATALOG_FIELDS) {
      if (data[field] !== undefined) catalog[field] = data[field];
    }
    batch.set(db.collection('stallCatalog').doc(stall.id), catalog, {
      merge: true,
    });
    ops++;
    total++;

    if (ops === 400) {
      // Firestore batches cap at 500 writes.
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();

  console.log(`Backfilled ${total} stallCatalog docs from vendorStalls.`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Backfill failed:', err);
    process.exit(1);
  });
