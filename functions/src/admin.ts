import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { validateOptionalText, FIELD_LIMITS } from './constants';
import { APP_CHECK_ENFORCED, rateLimit } from './security';

/**
 * Trusted admin operations for the Palengke Admin web portal (MEPO).
 *
 * Firestore rules deny client writes to `kycSubmissions`, `licenseRenewals`
 * and `users` account flags entirely — every admin mutation flows through
 * these callables: role-checked (users/{uid}.role == 'admin'), rate-limited,
 * transactional where two documents must agree, and stamped into the
 * `adminActions` audit collection (client-unwritable, admin-readable).
 */
const db = admin.firestore();

async function roleOf(uid: string): Promise<string | null> {
  const snap = await db.collection('users').doc(uid).get();
  return snap.exists ? (snap.data()?.role as string | null) : null;
}

async function requireAdmin(uid: string | undefined): Promise<void> {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  const role = await roleOf(uid);
  if (role !== 'admin') {
    throw new HttpsError('permission-denied', 'Admin access required');
  }
}

async function audit(
  uid: string,
  action: string,
  target: string,
  details: Record<string, unknown>,
): Promise<void> {
  await db.collection('adminActions').add({
    action,
    target,
    byUid: uid,
    at: FieldValue.serverTimestamp(),
    details,
  });
}

const STALL_SECTIONS = ['Wet Section', 'Dry Goods', 'Meat'];

/**
 * Approves or rejects a vendor KYC submission. Approval atomically marks the
 * submission reviewed AND flips the stall's KYC state + section allocation
 * (stall id == owner uid, so the stall doc is deterministic).
 */
export const approveKyc = onCall(
  { enforceAppCheck: APP_CHECK_ENFORCED },
  async (request) => {
    const uid = request.auth?.uid;
    await requireAdmin(uid);
    await rateLimit(uid!, 'approveKyc', 30);

    const data = request.data ?? {};
    const kycId: unknown = data.kycId;
    const decision: unknown = data.decision;
    if (typeof kycId !== 'string' || kycId.length === 0) {
      throw new HttpsError('invalid-argument', 'Missing kycId');
    }
    if (decision !== 'approved' && decision !== 'rejected') {
      throw new HttpsError(
        'invalid-argument',
        "decision must be 'approved' or 'rejected'",
      );
    }
    const textError =
      validateOptionalText(data.rejectionReason, FIELD_LIMITS.remarks, 'rejectionReason') ??
      validateOptionalText(data.stallNumber, 20, 'stallNumber') ??
      validateOptionalText(data.floorNumber, 20, 'floorNumber') ??
      validateOptionalText(data.section, 40, 'section');
    if (textError) {
      throw new HttpsError('invalid-argument', textError);
    }
    if (data.section !== undefined && !STALL_SECTIONS.includes(data.section)) {
      throw new HttpsError(
        'invalid-argument',
        `section must be one of: ${STALL_SECTIONS.join(', ')}`,
      );
    }
    if (decision === 'rejected' &&
      !(typeof data.rejectionReason === 'string' && data.rejectionReason.length > 0)) {
      throw new HttpsError(
        'invalid-argument',
        'A rejection reason is required when rejecting',
      );
    }

    const kycRef = db.collection('kycSubmissions').doc(kycId);
    const now = FieldValue.serverTimestamp();

    await db.runTransaction(async (tx) => {
      const kycSnap = await tx.get(kycRef);
      if (!kycSnap.exists) {
        throw new HttpsError('not-found', 'KYC submission not found');
      }
      const kyc = kycSnap.data()!;
      if (kyc.status === 'approved' || kyc.status === 'rejected') {
        throw new HttpsError(
          'already-exists',
          `Submission already ${kyc.status}`,
        );
      }
      const stallHolderId = kyc.stallHolderId as string | undefined;
      if (typeof stallHolderId !== 'string' || stallHolderId.length === 0) {
        throw new HttpsError(
          'failed-precondition',
          'Submission has no stall holder reference',
        );
      }

      tx.update(kycRef, {
        status: decision,
        rejectionReason:
          decision === 'rejected' ? data.rejectionReason : null,
        reviewedBy: uid,
        reviewedAt: now,
        updatedAt: now,
      });

      if (decision === 'approved') {
        // Stall id == owner uid: deterministic counterpart doc.
        const stallRef = db.collection('vendorStalls').doc(stallHolderId);
        tx.update(stallRef, {
          isKYCApproved: true,
          kycStatus: 'approved',
          ...(data.stallNumber !== undefined ? { stallNumber: data.stallNumber } : {}),
          ...(data.floorNumber !== undefined ? { floorNumber: data.floorNumber } : {}),
          ...(data.section !== undefined ? { section: data.section } : {}),
          updatedAt: now,
        });
      }
    });

    await audit(uid!, 'kyc.' + decision, kycId, { decision });
    return { kycId, status: decision as string };
  },
);

/**
 * Approves or rejects an annual license renewal. Approval activates the
 * stall's license and sets its expiry from the renewal's period end.
 */
export const approveRenewal = onCall(
  { enforceAppCheck: APP_CHECK_ENFORCED },
  async (request) => {
    const uid = request.auth?.uid;
    await requireAdmin(uid);
    await rateLimit(uid!, 'approveRenewal', 30);

    const data = request.data ?? {};
    const renewalId: unknown = data.renewalId;
    const decision: unknown = data.decision;
    if (typeof renewalId !== 'string' || renewalId.length === 0) {
      throw new HttpsError('invalid-argument', 'Missing renewalId');
    }
    if (decision !== 'approved' && decision !== 'rejected') {
      throw new HttpsError(
        'invalid-argument',
        "decision must be 'approved' or 'rejected'",
      );
    }
    const textError = validateOptionalText(
      data.rejectionReason,
      FIELD_LIMITS.remarks,
      'rejectionReason',
    );
    if (textError) {
      throw new HttpsError('invalid-argument', textError);
    }
    if (decision === 'rejected' &&
      !(typeof data.rejectionReason === 'string' && data.rejectionReason.length > 0)) {
      throw new HttpsError(
        'invalid-argument',
        'A rejection reason is required when rejecting',
      );
    }

    const renewalRef = db.collection('licenseRenewals').doc(renewalId);
    const now = FieldValue.serverTimestamp();

    await db.runTransaction(async (tx) => {
      const renewalSnap = await tx.get(renewalRef);
      if (!renewalSnap.exists) {
        throw new HttpsError('not-found', 'License renewal not found');
      }
      const renewal = renewalSnap.data()!;
      if (renewal.status === 'approved' || renewal.status === 'rejected') {
        throw new HttpsError(
          'already-exists',
          `Renewal already ${renewal.status}`,
        );
      }
      const stallId = renewal.stallId as string | undefined;
      if (typeof stallId !== 'string' || stallId.length === 0) {
        throw new HttpsError(
          'failed-precondition',
          'Renewal has no stall reference',
        );
      }

      tx.update(renewalRef, {
        status: decision,
        rejectionReason:
          decision === 'rejected' ? data.rejectionReason : null,
        reviewedBy: uid,
        reviewedAt: now,
        updatedAt: now,
      });

      if (decision === 'approved') {
        const periodEnd = renewal.periodEnd instanceof Timestamp
          ? renewal.periodEnd
          : null;
        tx.update(db.collection('vendorStalls').doc(stallId), {
          licenseStatus: 'active',
          ...(periodEnd ? { licenseExpiryDate: periodEnd } : {}),
          updatedAt: now,
        });
      }
    });

    await audit(uid!, 'renewal.' + decision, renewalId, { decision });
    return { renewalId, status: decision as string };
  },
);

/**
 * Blocks or unblocks a user account. Blocked users are rejected by every
 * trusted path (ordering, transitions, reviews). Admins cannot be blocked —
 * that is a lockout/privilege-escalation footgun better done in the console.
 */
export const setAccountBlocked = onCall(
  { enforceAppCheck: APP_CHECK_ENFORCED },
  async (request) => {
    const uid = request.auth?.uid;
    await requireAdmin(uid);
    await rateLimit(uid!, 'setAccountBlocked', 30);

    const data = request.data ?? {};
    const targetUid: unknown = data.uid;
    const blocked: unknown = data.blocked;
    if (typeof targetUid !== 'string' || targetUid.length === 0) {
      throw new HttpsError('invalid-argument', 'Missing uid');
    }
    if (typeof blocked !== 'boolean') {
      throw new HttpsError('invalid-argument', 'blocked must be a boolean');
    }

    const userRef = db.collection('users').doc(targetUid);
    const now = FieldValue.serverTimestamp();

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'User not found');
      }
      if (snap.data()?.role === 'admin') {
        throw new HttpsError(
          'permission-denied',
          'Admin accounts cannot be blocked from the portal',
        );
      }
      tx.update(userRef, { isBlocked: blocked, updatedAt: now });
    });

    await audit(uid!, blocked ? 'account.blocked' : 'account.unblocked', targetUid, {});
    return { uid: targetUid, isBlocked: blocked };
  },
);
