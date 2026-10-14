import {
  assertRole,
  bearerUid,
  err,
  handle,
  roleOf,
  supabase,
} from '../_shared/backend.ts'

type Json = Record<string, unknown>

async function requireAdmin(req: Request): Promise<{ uid: string; adminId: string; fullName: string; email: string }> {
  const uid = await bearerUid(req)
  assertRole(await roleOf(uid), ['admin'])

  const { data, error } = await supabase
    .from('admins')
    .select('admin_id,full_name,email')
    .eq('user_id', uid)
    .maybeSingle()
  if (error) throw error
  if (!data?.admin_id) {
    throw err('permission-denied', 'This admin account is not registered in Supabase')
  }
  return { uid, adminId: String(data.admin_id), fullName: String(data.full_name ?? ''), email: String(data.email ?? '') }
}

async function rows(
  table: string,
  columns = '*',
  orderBy?: string,
): Promise<unknown[]> {
  const result: unknown[] = []
  const pageSize = 500
  for (let offset = 0; ; offset += pageSize) {
    let query = supabase.from(table).select(columns)
    if (orderBy) query = query.order(orderBy, { ascending: false })
    const { data, error } = await query.range(offset, offset + pageSize - 1)
    if (error) throw error
    const page = data ?? []
    result.push(...page)
    if (page.length < pageSize) return result
  }
}

function requiredText(body: Json, key: string): string {
  const value = body[key]
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw err('invalid-argument', `${key} is required`)
  }
  return value.trim()
}

function optionalFacebookUrl(body: Json): string | null {
  const value = body.facebookUrl
  if (typeof value !== 'string' || value.trim() === '') return null
  let url: URL
  try {
    url = new URL(value.trim())
  } catch {
    throw err('invalid-argument', 'Facebook post link must be a valid URL')
  }
  if (url.protocol !== 'https:' ||
      !(url.hostname === 'facebook.com' || url.hostname.endsWith('.facebook.com'))) {
    throw err('invalid-argument', 'Facebook post link must use https://facebook.com')
  }
  return url.toString()
}

function popupImageUrls(body: Json): string[] {
  const value = body.popupImageUrls
  if (value === undefined) return []
  if (!Array.isArray(value) || value.length > 10) {
    throw err('invalid-argument', 'Popup gallery can contain at most 10 images')
  }
  return value.map((item) => {
    if (typeof item !== 'string') {
      throw err('invalid-argument', 'Popup image URL is invalid')
    }
    let url: URL
    try {
      url = new URL(item)
    } catch {
      throw err('invalid-argument', 'Popup image URL is invalid')
    }
    if (url.protocol !== 'https:') {
      throw err('invalid-argument', 'Popup image URLs must use HTTPS')
    }
    return url.toString()
  })
}

Deno.serve((req) => handle(req, async (request) => {
  if (request.method !== 'POST') throw err('invalid-argument', 'POST required')
  const { uid, adminId, fullName, email } = await requireAdmin(request)
  const body = await request.json() as Json
  const action = requiredText(body, 'action')

  if (action === 'verify-admin') return { adminId, fullName, email }

  if (action === 'accounts') {
    const [users, customers, stalls, orders] = await Promise.all([
      rows('users'), rows('customers'), rows('stall_holders'), rows('orders'),
    ])
    return { users, customers, stalls, orders }
  }
  if (action === 'applications') {
    const [applicationRows, stalls, users] = await Promise.all([
      rows('kyc_submissions', '*', 'submitted_at'),
      rows('stall_holders'), rows('users'),
    ])
    const documentFields = [
      'mayor_permit_url', 'sanitary_permit_url', 'fire_certification_url',
      'market_clearance_url', 'valid_id_photo_url', 'selfie_url',
    ]
    const applications = await Promise.all(applicationRows.map(async (value) => {
      const row = value as Record<string, unknown>
      const signed = { ...row }
      for (const field of documentFields) {
        const raw = row[field]
        if (typeof raw !== 'string' || raw.length === 0) continue
        const match = raw.match(/\/storage\/v1\/object\/(?:sign|public)\/kyc\/([^?]+)/)
        if (!match) continue
        try {
          const path = decodeURIComponent(match[1])
          const { data, error } = await supabase.storage.from('kyc').createSignedUrl(path, 3600)
          if (!error && data?.signedUrl) signed[field] = data.signedUrl
        } catch (error) {
          console.error(`Could not refresh KYC document URL for ${field}:`, error)
        }
      }
      return signed
    }))
    return { applications, stalls, users }
  }
  if (action === 'orders') {
    const [orders, items, stalls] = await Promise.all([
      rows('orders', '*', 'created_at'),
      rows('order_items'), rows('stall_holders'),
    ])
    return { orders, items, stalls }
  }
  if (action === 'announcements') {
    return { announcements: await rows('system_announcements', '*', 'created_at') }
  }

  if (action === 'set-account-blocked') {
    const userId = requiredText(body, 'userId')
    if (typeof body.blocked !== 'boolean') {
      throw err('invalid-argument', 'blocked must be a boolean')
    }
    if (userId === uid) throw err('failed-precondition', 'Admins cannot block themselves')
    const { data, error } = await supabase.from('users').update({
      is_blocked: body.blocked,
      updated_at: new Date().toISOString(),
    }).eq('user_id', userId).neq('role', 'admin').select('user_id').maybeSingle()
    if (error) throw error
    if (!data) throw err('not-found', 'Account not found or cannot be blocked')
    const { error: auditError } = await supabase.from('admin_activity_logs').insert({
      admin_id: adminId,
      action_type: body.blocked ? 'blocked_user' : 'unblocked_user',
      target_id: userId,
      target_type: 'user',
      remarks: 'Changed from admin portal',
    })
    if (auditError) throw auditError
    return { userId, blocked: body.blocked }
  }

  if (action === 'review-kyc') {
    const kycId = requiredText(body, 'kycId')
    const status = requiredText(body, 'status')
    if (!['approved', 'rejected', 'pending'].includes(status)) {
      throw err('invalid-argument', 'status must be approved, rejected, or pending')
    }
    const rejectionReason = status === 'rejected'
      ? requiredText(body, 'rejectionReason')
      : null
    const { data, error } = await supabase.from('kyc_submissions').update({
      status,
      rejection_reason: rejectionReason,
      reviewed_by: status === 'pending' ? null : adminId,
      reviewed_at: status === 'pending' ? null : new Date().toISOString(),
    }).eq('kyc_id', kycId).select('kyc_id,stall_holder_id').maybeSingle()
    if (error) throw error
    if (!data) throw err('not-found', 'KYC application not found')
    if (status === 'pending') {
      const { error: stallError } = await supabase.from('stall_holders').update({
        kyc_status: 'pending',
        is_kyc_approved: false,
      }).eq('stall_holder_id', data.stall_holder_id)
      if (stallError) throw stallError
    }
    if (status === 'approved' || status === 'rejected') {
      const { error: auditError } = await supabase.from('admin_activity_logs').insert({
        admin_id: adminId,
        action_type: status === 'approved' ? 'approved_kyc' : 'rejected_kyc',
        target_id: kycId,
        target_type: 'kyc',
        remarks: rejectionReason,
      })
      if (auditError) throw auditError
    }
    return { kycId, status }
  }

  if (action === 'publish-announcement') {
    const { data, error } = await supabase.from('system_announcements').insert({
      admin_id: adminId,
      title: requiredText(body, 'title'),
      body: requiredText(body, 'body'),
      target_audience: requiredText(body, 'audience'),
      expires_at: body.expiresAt ?? null,
      image_url: body.imageUrl ?? null,
      show_as_popup: body.showAsPopup === true,
      facebook_url: optionalFacebookUrl(body),
      popup_image_urls: popupImageUrls(body),
    }).select().single()
    if (error) throw error
    return data
  }

  if (action === 'update-announcement') {
    const id = requiredText(body, 'id')
    const changes: Json = {
      title: requiredText(body, 'title'),
      body: requiredText(body, 'body'),
      target_audience: requiredText(body, 'audience'),
      expires_at: body.expiresAt ?? null,
    }
    if (typeof body.showAsPopup === 'boolean') {
      changes.show_as_popup = body.showAsPopup
    }
    if ('facebookUrl' in body) changes.facebook_url = optionalFacebookUrl(body)
    if ('popupImageUrls' in body) {
      changes.popup_image_urls = popupImageUrls(body)
    }
    if (body.clearImage === true) changes.image_url = null
    else if (typeof body.imageUrl === 'string' && body.imageUrl.length > 0) {
      changes.image_url = body.imageUrl
    }
    const { data, error } = await supabase.from('system_announcements')
      .update(changes).eq('announcement_id', id).select('announcement_id').maybeSingle()
    if (error) throw error
    if (!data) throw err('not-found', 'Announcement not found')
    return { id }
  }

  if (action === 'delete-announcement') {
    const id = requiredText(body, 'id')
    const { data, error } = await supabase.from('system_announcements')
      .delete().eq('announcement_id', id).select('announcement_id').maybeSingle()
    if (error) throw error
    if (!data) throw err('not-found', 'Announcement not found')
    return { id }
  }

  throw err('invalid-argument', `Unknown action: ${action}`)
}))
