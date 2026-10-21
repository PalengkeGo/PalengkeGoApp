import { bearerUid, err, handle, isBlocked, roleOf, supabase } from '../_shared/backend.ts'
import { validateSupportReportInput } from '../_shared/support_reports.ts'
import { validateEvidencePaths } from '../_shared/complaints.ts'
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
    await rateLimit(uid, 'reportSupportIssue', 5)

    const data = await req.json().catch(() => null)
    const input = validateSupportReportInput(data)
    const evidencePaths = validateEvidencePaths(
      (data as Record<string, unknown> | null)?.evidencePaths,
      uid,
    )
    const { data: report, error } = await supabase
      .from('vendor_complaints')
      .insert({
        reporter_user_id: uid,
        stall_holder_id: null,
        report_type: 'support',
        reason: input.topic,
        details: input.details,
        evidence_paths: evidencePaths,
      })
      .select('complaint_id')
      .single()
    if (error) throw error
    return { complaintId: report.complaint_id, status: 'open' }
  }),
)
