/**
 * Trusted admin account blocking/unblocking (ported from functions/src/admin.ts setAccountBlocked).
 *
 * Blocks or unblocks a user account.
 */

import { assertRole, audit, bearerUid, db, err, FieldValue, handle, rateLimit, roleOf } from '../_shared/backend.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    const role = await roleOf(uid)
    assertRole(role, ['admin'])
    await rateLimit(db, uid, 'setAccountBlocked', 30)

    const data = await req.json().catch(() => ({}))
    const targetUid: unknown = data.uid
    const blocked: unknown = data.blocked
    if (typeof targetUid !== 'string' || targetUid.length === 0) {
      throw err('invalid-argument', 'Missing uid')
    }
    if (typeof blocked !== 'boolean') {
      throw err('invalid-argument', 'blocked must be a boolean')
    }

    const userRef = db.collection('users').doc(targetUid)
    const now = FieldValue.serverTimestamp()

    await db.runTransaction(async (tx: any) => {
      const snap = await tx.get(userRef)
      if (!snap.exists) {
        throw err('not-found', 'User not found')
      }
      if (snap.data()?.role === 'admin') {
        throw err('permission-denied', 'Admin accounts cannot be blocked from the portal')
      }
      tx.update(userRef, { isBlocked: blocked, updatedAt: now })
    })

    await audit(uid, blocked ? 'account.blocked' : 'account.unblocked', targetUid, {})
    return { uid: targetUid, isBlocked: blocked }
  }),
)