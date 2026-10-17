import { bearerUid, err, handle, isBlocked, roleOf, supabase } from '../_shared/backend.ts'
import { validateVendorComplaintInput } from '../_shared/complaints.ts'
import { rateLimit } from '../_shared/security.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    if (req.method !== 'POST') throw err('invalid-argument', 'POST required')
    const uid = await bearerUid(req)
    if (await isBlocked(uid)) throw err('permission-denied', 'Your account is blocked')

    const role = await roleOf(uid)
    if (!role || !['customer', 'vendor', 'stallholder'].includes(role)) {
      throw err('permission-denied', 'An active customer or stall-holder account is required')
    }
    await rateLimit(uid, 'reportVendor', 5)

    const data = await req.json().catch(() => null)
    const input = validateVendorComplaintInput(data)
    const { data: stall, error: stallError } = await supabase
      .from('stall_holders')
      .select('stall_holder_id,user_id')
      .eq('stall_holder_id', input.stallId)
      .maybeSingle()
    if (stallError) throw stallError
    if (!stall) throw err('not-found', 'Vendor not found')
    if (stall.user_id === uid) {
      throw err('failed-precondition', 'You cannot report your own stall')
    }

    const { data: complaint, error } = await supabase
      .from('vendor_complaints')
      .insert({
        reporter_user_id: uid,
        stall_holder_id: input.stallId,
        reason: input.reason,
        details: input.details,
      })
      .select('complaint_id')
      .single()
    if (error) throw error
    return { complaintId: complaint.complaint_id, status: 'open' }
  }),
)
