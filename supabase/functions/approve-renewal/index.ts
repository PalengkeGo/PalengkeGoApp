/**
 * Trusted admin license renewal approval (ported from functions/src/admin.ts approveRenewal).
 *
 * Approves or rejects a vendor license renewal request.
 */

import { assertRole, audit, bearerUid, db, err, FieldValue, handle, rateLimit, roleOf, Timestamp } from '../_shared/backend.ts'
import { FIELD_LIMITS, validateOptionalText } from '../_shared/constants.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    const role = await roleOf(uid)
    assertRole(role, ['admin'])
    await rateLimit(db, uid, 'approveRenewal', 30)

    const data = await req.json().catch(() => ({}))
    const renewalId: unknown = data.renewalId
    const decision: unknown = data.decision
    if (typeof renewalId !== 'string' || renewalId.length === 0) {
      throw err('invalid-argument', 'Missing renewalId')
    }
    if (decision !== 'approved' && decision !== 'rejected') {
      throw err('invalid-argument', "decision must be 'approved' or 'rejected'")
    }
    const textError = validateOptionalText(data.rejectionReason, FIELD_LIMITS.remarks, 'rejectionReason')
    if (textError) {
      throw err('invalid-argument', textError)
    }

    const renewalRef = db.collection('licenseRenewals').doc(renewalId)
    const now = FieldValue.serverTimestamp()

    await db.runTransaction(async (tx: any) => {
      const renewalSnap = await tx.get(renewalRef)
      if (!renewalSnap.exists) {
        throw err('not-found', 'License renewal not found')
      }
      const renewal = renewalSnap.data()!
      if (renewal.status === 'approved' || renewal.status === 'rejected') {
        throw err('already-exists', `Renewal already ${renewal.status}`)
      }
      const stallId = renewal.stallId as string | undefined
      if (typeof stallId !== 'string' || stallId.length === 0) {
        throw err('failed-precondition', 'Renewal has no stall reference')
      }

      tx.update(renewalRef, {
        status: decision,
        rejectionReason: decision === 'rejected' ? data.rejectionReason ?? null : null,
        reviewedBy: uid,
        reviewedAt: now,
        updatedAt: now,
      })

      if (decision === 'approved') {
        const stallRef = db.collection('vendorStalls').doc(stallId)
        const stallSnap = await tx.get(stallRef)
        if (!stallSnap.exists) {
          throw err('failed-precondition', 'Stall not found for this renewal — approve the KYC submission first')
        }
        const periodEnd = renewal.periodEnd instanceof Timestamp ? renewal.periodEnd : null
        tx.update(stallRef, {
          licenseStatus: 'active',
          ...(periodEnd ? { licenseExpiryDate: periodEnd } : {}),
          updatedAt: now,
        })
      }
    })

    await audit(uid, 'renewal.' + decision, renewalId, { decision })
    return { renewalId, status: decision as string }
  }),
)