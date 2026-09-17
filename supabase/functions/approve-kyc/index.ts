/**
 * Trusted admin KYC approval (ported from functions/src/admin.ts approveKyc).
 *
 * Approves or rejects a vendor KYC submission. Approval atomically marks the
 * submission reviewed, PROMOTES the applicant's role to vendor, and upserts
 * the stall doc with its KYC state + section allocation.
 */

import { assertRole, audit, bearerUid, db, err, FieldValue, handle, rateLimit, roleOf } from '../_shared/backend.ts'
import { FIELD_LIMITS, validateOptionalText } from '../_shared/constants.ts'

const STALL_SECTIONS = ['Wet Section', 'Dry Goods', 'Meat']

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    const role = await roleOf(uid)
    assertRole(role, ['admin'])
    await rateLimit(db, uid, 'approveKyc', 30)

    const data = await req.json().catch(() => ({}))
    const kycId: unknown = data.kycId
    const decision: unknown = data.decision
    if (typeof kycId !== 'string' || kycId.length === 0) {
      throw err('invalid-argument', 'Missing kycId')
    }
    if (decision !== 'approved' && decision !== 'rejected') {
      throw err('invalid-argument', "decision must be 'approved' or 'rejected'")
    }
    const textError =
      validateOptionalText(data.rejectionReason, FIELD_LIMITS.remarks, 'rejectionReason') ??
      validateOptionalText(data.stallNumber, 20, 'stallNumber') ??
      validateOptionalText(data.floorNumber, 20, 'floorNumber') ??
      validateOptionalText(data.section, 40, 'section')
    if (textError) {
      throw err('invalid-argument', textError)
    }
    if (data.section !== undefined && !STALL_SECTIONS.includes(data.section)) {
      throw err('invalid-argument', `section must be one of: ${STALL_SECTIONS.join(', ')}`)
    }

    const kycRef = db.collection('kycSubmissions').doc(kycId)
    const now = FieldValue.serverTimestamp()

    const applicantUid: string = await db.runTransaction(async (tx: any) => {
      const kycSnap = await tx.get(kycRef)
      if (!kycSnap.exists) {
        throw err('not-found', 'KYC submission not found')
      }
      const kyc = kycSnap.data()!
      if (kyc.status === 'approved' || kyc.status === 'rejected') {
        throw err('already-exists', `KYC submission already ${kyc.status}`)
      }
      const applicantUid = kyc.uid as string | undefined
      if (typeof applicantUid !== 'string' || applicantUid.length === 0) {
        throw err('failed-precondition', 'KYC submission has no applicant UID')
      }

      tx.update(kycRef, {
        status: decision,
        rejectionReason: decision === 'rejected' ? data.rejectionReason ?? null : null,
        reviewedBy: uid,
        reviewedAt: now,
        updatedAt: now,
      })

      if (decision === 'approved') {
        const userRef = db.collection('users').doc(applicantUid)
        tx.update(userRef, { role: 'vendor', updatedAt: now })

        const stallRef = db.collection('vendorStalls').doc(applicantUid)
        const stallSnap = await tx.get(stallRef)
        const stallData = stallSnap.exists ? stallSnap.data()! : {}

        tx.set(
          stallRef,
          {
            ...stallData,
            ownerUid: applicantUid,
            vendorName: kyc.businessName || stallData.vendorName || 'New Stall',
            stallNumber: data.stallNumber || kyc.stallNumber || stallData.stallNumber || '',
            floorNumber: data.floorNumber || kyc.floorNumber || stallData.floorNumber || '',
            section: data.section || kyc.section || stallData.section || 'Wet Section',
            kycStatus: 'approved',
            updatedAt: now,
          },
          { merge: true },
        )
      }

      return applicantUid
    })

    await audit(uid, 'kyc.' + decision, kycId, { applicantUid, decision })
    return { kycId, status: decision as string, applicantUid }
  }),
)