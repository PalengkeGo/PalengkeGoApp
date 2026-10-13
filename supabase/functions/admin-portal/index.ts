import {
  assertRole,
  bearerUid,
  err,
  handle,
  roleOf,
  supabase,
} from '../_shared/backend.ts'

type Json = Record<string, unknown>

async function requireAdmin(req: Request): Promise<{ uid: string; adminId: string }> {
  const uid = await bearerUid(req)
  assertRole(await roleOf(uid), ['admin'])

  const { data, error } = await supabase
    .from('admins')
    .select('admin_id')
    .eq('user_id', uid)
    .maybeSingle()
  if (error) throw error
  if (!data?.admin_id) {
    throw err('permission-denied', 'This admin account is not registered in Supabase')
  }
  return { uid, adminId: String(data.admin_id) }
}

async function rows(table: string, columns = '*'): Promise<unknown[]> {
  const { data, error } = await supabase.from(table).select(columns)
  if (error) throw error
  return data ?? []
}

function requiredText(body: Json, key: string): string {
  const value = body[key]
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw err('invalid-argument', `${key} is required`)
  }
  return value.trim()
}

Deno.serve((req) => handle(req, async (request) => {
  if (request.method !== 'POST') throw err('invalid-argument', 'POST required')
  const { uid, adminId } = await requireAdmin(request)
  const body = await request.json() as Json
  const action = requiredText(body, 'action')

  if (action === 'accounts') {
    const [users, customers, stalls, orders] = await Promise.all([
      rows('users'), rows('customers'), rows('stall_holders'), rows('orders'),
    ])
    return { users, customers, stalls, orders }
  }
  if (action === 'applications') {
    const [applicationResult, stalls, users] = await Promise.all([
      supabase.from('kyc_submissions').select('*')
        .order('submitted_at', { ascending: false }),
      rows('stall_holders'), rows('users'),
    ])
    if (applicationResult.error) throw applicationResult.error
    return { applications: applicationResult.data ?? [], stalls, users }
  }
  if (action === 'orders') {
    const [orderResult, items, stalls] = await Promise.all([
      supabase.from('orders').select('*').order('created_at', { ascending: false }),
      rows('order_items'), rows('stall_holders'),
    ])
    if (orderResult.error) throw orderResult.error
    return { orders: orderResult.data ?? [], items, stalls }
  }
  if (action === 'announcements') {
    const { data, error } = await supabase.from('system_announcements')
      .select('*').order('created_at', { ascending: false })
    if (error) throw error
    return { announcements: data ?? [] }
  }

  if (action === 'set-account-blocked') {
    const userId = requiredText(body, 'userId')
    if (typeof body.blocked !== 'boolean') {
      throw err('invalid-argument', 'blocked must be a boolean')
    }
    if (userId === uid) throw err('failed-precondition', 'Admins cannot block themselves')
    const { error } = await supabase.from('users').update({
      is_blocked: body.blocked,
      updated_at: new Date().toISOString(),
    }).eq('user_id', userId).neq('role', 'admin')
    if (error) throw error
    return { userId, blocked: body.blocked }
  }

  if (action === 'review-kyc') {
    const kycId = requiredText(body, 'kycId')
    const status = requiredText(body, 'status')
    if (status !== 'approved' && status !== 'rejected') {
      throw err('invalid-argument', 'status must be approved or rejected')
    }
    const rejectionReason = status === 'rejected'
      ? requiredText(body, 'rejectionReason')
      : null
    const { error } = await supabase.from('kyc_submissions').update({
      status,
      rejection_reason: rejectionReason,
      reviewed_by: adminId,
      reviewed_at: new Date().toISOString(),
    }).eq('kyc_id', kycId)
    if (error) throw error
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
    if (body.clearImage === true) changes.image_url = null
    else if (typeof body.imageUrl === 'string' && body.imageUrl.length > 0) {
      changes.image_url = body.imageUrl
    }
    const { error } = await supabase.from('system_announcements')
      .update(changes).eq('announcement_id', id)
    if (error) throw error
    return { id }
  }

  if (action === 'delete-announcement') {
    const id = requiredText(body, 'id')
    const { error } = await supabase.from('system_announcements')
      .delete().eq('announcement_id', id)
    if (error) throw error
    return { id }
  }

  throw err('invalid-argument', `Unknown action: ${action}`)
}))
