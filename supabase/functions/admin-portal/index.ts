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

async function recordAdminActivity(
  adminId: string,
  actionType: string,
  targetId: string | null,
  targetType: string | null,
  remarks: string,
): Promise<void> {
  const { error } = await supabase.from('admin_activity_logs').insert({
    admin_id: adminId,
    action_type: actionType,
    target_id: targetId,
    target_type: targetType,
    remarks,
  })
  if (error) throw error
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

async function sendAccountPush(
  userId: string,
  notificationId: string,
  title: string,
  body: string,
  type = 'account_restriction',
): Promise<void> {
  const serviceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
  if (!serviceAccount) {
    console.error('FIREBASE_SERVICE_ACCOUNT is not configured; account push was not sent')
    return
  }
  try {
    // Dynamic imports avoid the wildcard npm ambient module in the editor
    // masking firebase-admin's named exports.
    const { cert, getApps, initializeApp } = await import('npm:firebase-admin@12.7.0/app')
    const { getMessaging } = await import('npm:firebase-admin@12.7.0/messaging')
    if (!getApps().length) initializeApp({ credential: cert(JSON.parse(serviceAccount)) })
    const { data: devices, error } = await supabase
      .from('account_device_tokens')
      .select('token')
      .eq('user_id', userId)
    if (error) throw error
    const tokens = (devices ?? []).map((device) => String(device.token)).filter(Boolean)
    for (let offset = 0; offset < tokens.length; offset += 500) {
      const batch = tokens.slice(offset, offset + 500)
      const result = await getMessaging().sendEachForMulticast({
        tokens: batch,
        notification: { title, body },
        data: { type, notification_id: notificationId, title, body },
        android: {
          priority: 'high',
          notification: { channelId: 'palengkego_account_updates' },
        },
        apns: { payload: { aps: { sound: 'default' } } },
      })
      const expiredTokens = batch.filter((_, index) => {
        const failure = result.responses[index]
        return !failure.success && [
          'messaging/registration-token-not-registered',
          'messaging/invalid-registration-token',
        ].includes(failure.error?.code ?? '')
      })
      if (expiredTokens.length) {
        await supabase.from('account_device_tokens').delete().in('token', expiredTokens)
      }
    }
  } catch (error) {
    // The moderation transaction is already committed. A push outage must not
    // hide the durable in-app notification or make the admin retry the action.
    console.error('Could not send account moderation push:', error)
  }
}

Deno.serve((req: Request) => handle(req, async (request) => {
  if (request.method !== 'POST') throw err('invalid-argument', 'POST required')
  const { uid, adminId, fullName, email } = await requireAdmin(request)
  const body = await request.json() as Json
  const action = requiredText(body, 'action')

  if (action === 'verify-admin') return { adminId, fullName, email }

  if (action === 'audit-logs') {
    const [{ data: logs, error: logError }, admins] = await Promise.all([
      supabase.from('admin_activity_logs').select('*')
        .order('performed_at', { ascending: false }).limit(500),
      rows('admins', 'admin_id,full_name,email'),
    ])
    if (logError) throw logError
    const adminById = new Map(admins.map((value) => {
      const admin = value as Record<string, unknown>
      return [String(admin.admin_id), {
        name: String(admin.full_name ?? 'Administrator'),
        email: String(admin.email ?? ''),
      }] as const
    }))
    return {
      auditLogs: (logs ?? []).map((log) => ({
        ...log,
        admin_name: adminById.get(String(log.admin_id))?.name ?? 'Administrator',
        admin_email: adminById.get(String(log.admin_id))?.email ?? '',
      })),
    }
  }

  if (action === 'record-audit') {
    const actionType = requiredText(body, 'actionType')
    const allowedAuditTypes = [
      'admin_logged_in', 'admin_logged_out', 'exported_report',
      'updated_admin_profile', 'published_announcement',
      'updated_announcement', 'deleted_announcement',
    ]
    if (!allowedAuditTypes.includes(actionType)) {
      throw err('invalid-argument', 'Unsupported audit action')
    }
    const targetType = actionType.startsWith('admin_logged_')
      ? 'authentication'
      : actionType === 'exported_report' ? 'report' : 'system'
    const remarks = typeof body.remarks === 'string' ? body.remarks.trim().slice(0, 1000) : ''
    await recordAdminActivity(
      adminId,
      actionType,
      adminId,
      targetType,
      remarks,
    )
    return { actionType }
  }

  if (action === 'update-admin-profile') {
    const fullName = requiredText(body, 'fullName')
    if (fullName.length > 120) {
      throw err('invalid-argument', 'Admin name must be 120 characters or fewer')
    }
    const { data, error } = await supabase.from('admins')
      .update({ full_name: fullName })
      .eq('admin_id', adminId)
      .select('admin_id')
      .maybeSingle()
    if (error) throw error
    if (!data) throw err('not-found', 'Admin profile not found')
    try {
      await recordAdminActivity(
        adminId,
        'updated_admin_profile',
        adminId,
        'system',
        `Updated administrator profile name to ${fullName}`,
      )
    } catch (auditError) {
      console.error('Could not record admin profile update:', auditError)
    }
    return { fullName }
  }

  if (action === 'accounts') {
    const [users, customers, stalls, orders, notes, suspensions] = await Promise.all([
      rows('users'), rows('customers'), rows('stall_holders'), rows('orders'),
      rows('account_admin_notes'), rows('account_suspensions', '*', 'created_at'),
    ])
    return { users, customers, stalls, orders, notes, suspensions }
  }
  if (action === 'stall-products') {
    const userId = requiredText(body, 'userId')
    const { data: stalls, error: stallError } = await supabase.from('stall_holders')
      .select('stall_holder_id,stall_name,stall_number,floor_number')
      .eq('user_id', userId)
    if (stallError) throw stallError
    if (!stalls?.length) throw err('not-found', 'No stall is linked to this account')
    const stallRows = stalls as Array<{
      stall_holder_id: string
      stall_name: string | null
      stall_number: string | null
      floor_number: string | null
    }>
    const stallById = new Map(
      stallRows.map((stall) => [String(stall.stall_holder_id), stall] as const),
    )
    const { data: products, error: productError } = await supabase.from('products')
      .select('product_id,stall_holder_id,product_name,description,category_tag,price_per_kg,price_per_piece,unit,image_url,stock_quantity,is_in_stock,is_visible,updated_at')
      .in('stall_holder_id', [...stallById.keys()])
      .order('product_name')
    if (productError) throw productError
    return {
      products: (products ?? []).map((product) => {
        const stall = stallById.get(String(product.stall_holder_id))
        const image = typeof product.image_url === 'string' ? product.image_url : ''
        const imageUrl = image.startsWith('https://')
          ? image
          : image ? supabase.storage.from('stalls').getPublicUrl(image).data.publicUrl : null
        const location = [
          stall?.floor_number ? `Block ${stall.floor_number}` : '',
          stall?.stall_number ? `Stall ${stall.stall_number}` : '',
        ].filter(Boolean).join(' - ')
        return {
          ...product,
          image_url: imageUrl,
          stall_name: stall?.stall_name ?? '',
          stall_location: location,
        }
      }),
    }
  }
  if (action === 'warn-product-price') {
    const productId = requiredText(body, 'productId')
    const message = requiredText(body, 'message')
    if (message.length > 500) throw err('invalid-argument', 'Warning must be 500 characters or fewer')
    const { data: product, error: productError } = await supabase.from('products')
      .select('product_id,stall_holder_id,product_name,unit,price_per_kg,price_per_piece')
      .eq('product_id', productId)
      .maybeSingle()
    if (productError) throw productError
    if (!product) throw err('not-found', 'Product not found')
    const { data: stall, error: stallError } = await supabase.from('stall_holders')
      .select('user_id')
      .eq('stall_holder_id', product.stall_holder_id)
      .maybeSingle()
    if (stallError) throw stallError
    if (!stall?.user_id) throw err('not-found', 'Product owner account not found')
    const isPiece = product.unit === 'piece' || product.unit === 'pc'
    const price = isPiece ? product.price_per_piece : product.price_per_kg
    if (typeof price !== 'number' || !Number.isFinite(price) || price < 0) {
      throw err('failed-precondition', 'This product has no valid listed price to review')
    }
    const unit = isPiece ? 'piece' : 'kg'
    const title = 'Product price warning'
    let mepoPricePostUrl: string | null = null
    try {
      const { data: announcements, error: announcementError } = await supabase
        .from('system_announcements')
        .select('title,body,target_audience,facebook_url,expires_at,created_at')
        .not('facebook_url', 'is', null)
        .order('created_at', { ascending: false })
        .limit(25)
      if (announcementError) throw announcementError
      const pricePostRows = (announcements ?? []) as Array<{
        title: string | null
        body: string | null
        target_audience: string | null
        facebook_url: string | null
        expires_at: string | null
      }>
      const pricePost = pricePostRows.find((announcement) => {
        const audience = String(announcement.target_audience ?? '').toLowerCase()
        const content = `${announcement.title ?? ''} ${announcement.body ?? ''}`.toLowerCase()
        const isActive = announcement.expires_at == null ||
          Date.parse(announcement.expires_at) >= Date.now()
        return (audience === 'all' || audience === 'stallholders') &&
          isActive && (content.includes('price') || content.includes('monitor')) &&
          typeof announcement.facebook_url === 'string' &&
          announcement.facebook_url.startsWith('https://')
      })
      if (pricePost) mepoPricePostUrl = String(pricePost.facebook_url)
    } catch (error) {
      // The warning remains useful without an optional MEPO reference link.
      console.error('Could not find the latest MEPO price monitoring post:', error)
    }
    const notificationBody = `Price review for ${product.product_name}: Your listed price is ₱${price.toFixed(2)} per ${unit}. ${message}${mepoPricePostUrl ? `\n\nMEPO weekly price monitoring: ${mepoPricePostUrl}` : ''}`
    const { data: notification, error: notificationError } = await supabase.from('notifications')
      .insert({
        user_id: stall.user_id,
        title,
        body: notificationBody,
        type: 'account_action',
        reference_id: productId,
      })
      .select('notification_id')
      .single()
    if (notificationError) throw notificationError
    const { error: auditError } = await supabase.from('admin_activity_logs').insert({
      admin_id: adminId,
      action_type: 'warned_user',
      target_id: stall.user_id,
      target_type: 'user',
      remarks: `${product.product_name} (${Number(price).toFixed(2)} per ${unit}): ${message}`,
    })
    if (auditError) console.error('Could not record product price warning:', auditError)
    await sendAccountPush(
      String(stall.user_id),
      String(notification.notification_id),
      title,
      notificationBody,
      'product_price_warning',
    )
    return { productId, userId: String(stall.user_id), notificationId: notification.notification_id }
  }
  if (action === 'account-history') {
    const userId = requiredText(body, 'userId')
    const { data: user, error: userError } = await supabase.from('users').select('user_id,created_at').eq('user_id', userId).single()
    if (userError) throw userError
    const { data: stalls, error: stallError } = await supabase.from('stall_holders').select('stall_holder_id').eq('user_id', userId)
    if (stallError) throw stallError
    const { data: customers, error: customerError } = await supabase.from('customers').select('customer_id').eq('user_id', userId)
    if (customerError) throw customerError
    const targetIds = [userId, ...(stalls ?? []).map(s => s.stall_holder_id)]
    const { data: logs, error: logError } = await supabase.from('admin_activity_logs').select('*')
      .in('target_id', targetIds).order('performed_at', { ascending: false }).limit(50)
    if (logError) throw logError
    const activity = [{ title: 'Account registered', at: user.created_at }, ...(logs ?? []).map(l => ({
      title: String(l.action_type).replaceAll('_', ' '), at: l.performed_at,
    }))]
    let orderQuery = supabase.from('orders').select('order_id,order_status,created_at').order('created_at', { ascending: false }).limit(20)
    if (stalls?.length) orderQuery = orderQuery.in('stall_holder_id', stalls.map(s => s.stall_holder_id))
    else orderQuery = orderQuery.in('customer_id', [userId, ...(customers ?? []).map(c => c.customer_id)])
    const { data: orders, error: orderError } = await orderQuery
    if (orderError) throw orderError
    activity.push(...(orders ?? []).map(o => ({ title: `Order ${o.order_id}: ${o.order_status}`, at: o.created_at })))
    activity.sort((a,b) => Date.parse(b.at)-Date.parse(a.at))
    const violations = (logs ?? []).filter(l => ['warned_user','blocked_user','suspended_user','suspended_vendor'].includes(l.action_type))
      .map(l => ({ title: String(l.action_type).replaceAll('_',' '), detail: l.remarks ?? '', at: l.performed_at }))
    return { activity: activity.slice(0,20), violations }
  }
  if (action === 'moderate-account' || action === 'set-account-blocked') {
    const userId = requiredText(body, 'userId')
    if (action === 'set-account-blocked' && typeof body.blocked !== 'boolean') throw err('invalid-argument','blocked must be a boolean')
    const operation = action === 'set-account-blocked' ? (body.blocked ? 'block' : 'unblock') : requiredText(body,'operation')
    if (!['notes','block','unblock','suspend','lift'].includes(operation)) throw err('invalid-argument','Invalid account action')
    if (body.notes != null && (typeof body.notes !== 'string' || body.notes.length > (operation === 'suspend' ? 300 : 500))) throw err('invalid-argument','Invalid internal note')
    if (body.notifyUser != null && typeof body.notifyUser !== 'boolean') throw err('invalid-argument','Invalid notification setting')
    if (operation === 'suspend' && (typeof body.reason !== 'string' || !body.reason.trim() || body.reason.length > 120 ||
      typeof body.startDate !== 'string' || typeof body.endDate !== 'string' ||
      !Number.isFinite(Date.parse(body.startDate)) || !Number.isFinite(Date.parse(body.endDate)))) throw err('invalid-argument','A reason and valid start/end times are required')
    const { error } = await supabase.rpc('moderate_account', {
      p_actor: uid, p_user: userId, p_action: operation, p_notes: body.notes ?? null,
      p_reason: body.reason ?? '', p_start: body.startDate ?? null, p_end: body.endDate ?? null,
      p_notify: body.notifyUser ?? true, p_suspension: body.suspensionId ?? null,
    })
    if (error) throw err('failed-precondition', error.message)
    if (['block', 'unblock', 'suspend', 'lift'].includes(operation) &&
        (body.notifyUser ?? true)) {
      const title = operation === 'block' ? 'Account blocked'
        : operation === 'unblock' ? 'Account restored'
        : operation === 'suspend' ? 'Account suspension'
        : 'Suspension lifted'
      const { data: notification, error: notificationError } = await supabase
        .from('notifications')
        .select('notification_id,body')
        .eq('user_id', userId)
        .eq('title', title)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()
      if (notificationError) console.error('Could not read account notification for push:', notificationError)
      else if (notification) await sendAccountPush(
        userId,
        String(notification.notification_id),
        title,
        String(notification.body ?? ''),
      )
    }
    return { userId, operation }
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
  if (action === 'complaints') {
    const [complaints, stalls, users, admins, notifications] = await Promise.all([
      rows('vendor_complaints', '*', 'created_at'),
      rows('stall_holders', 'stall_holder_id,stall_name'),
      rows('users', 'user_id,full_name,email'),
      rows('admins', 'user_id'),
      rows('notifications', 'notification_id,user_id,title,body,type,reference_id,is_read,created_at', 'created_at'),
    ])
    const stallById = new Map(stalls.map((value) => {
      const row = value as Record<string, unknown>
      return [String(row.stall_holder_id), String(row.stall_name ?? 'Vendor')] as const
    }))
    const userById = new Map(users.map((value) => {
      const row = value as Record<string, unknown>
      return [String(row.user_id), String(row.full_name ?? row.email ?? 'Customer')] as const
    }))
    const adminUserIds = new Set(admins.map((value) =>
      String((value as Record<string, unknown>).user_id),
    ))
    return {
      complaints: await Promise.all(complaints.map(async (value) => {
        const row = value as Record<string, unknown>
        const evidencePaths = Array.isArray(row.evidence_paths)
          ? row.evidence_paths.filter((path): path is string => typeof path === 'string').slice(0, 5)
          : []
        const evidenceUrls = await Promise.all(evidencePaths.map(async (path) => {
          const { data, error } = await supabase.storage.from('report-evidence').createSignedUrl(path, 3600)
          if (error) {
            console.error('Could not sign report evidence:', error)
            return null
          }
          return data?.signedUrl ?? null
        }))
        return {
          ...row,
          evidence_urls: evidenceUrls.filter((url): url is string => typeof url === 'string'),
          stall_name: row.stall_holder_id == null
            ? 'Help & Support'
            : stallById.get(String(row.stall_holder_id)) ?? 'Vendor',
          reporter_name: userById.get(String(row.reporter_user_id)) ?? 'Customer',
        }
      })),
      notifications: notifications.filter((value) => {
        const row = value as Record<string, unknown>
        return row.type === 'complaint' && adminUserIds.has(String(row.user_id))
      }),
    }
  }
  if (action === 'notifications') {
    const { data, error } = await supabase.from('notifications')
      .select('notification_id,title,body,type,reference_id,is_read,created_at')
      .eq('user_id', uid)
      .order('created_at', { ascending: false })
      .limit(500)
    if (error) throw error
    return { notifications: data ?? [] }
  }
  if (action === 'review-complaint') {
    const complaintId = requiredText(body, 'complaintId')
    const status = requiredText(body, 'status')
    if (!['reviewing', 'resolved', 'dismissed'].includes(status)) {
      throw err('invalid-argument', 'status must be reviewing, resolved, or dismissed')
    }
    const notes = body.adminNotes
    if (notes !== undefined && (typeof notes !== 'string' || notes.length > 2000)) {
      throw err('invalid-argument', 'adminNotes must be 2000 characters or fewer')
    }
    const { data, error } = await supabase.from('vendor_complaints').update({
      status,
      reviewed_by: adminId,
      reviewed_at: new Date().toISOString(),
      admin_notes: typeof notes === 'string' && notes.trim() ? notes.trim() : null,
    }).eq('complaint_id', complaintId).select('complaint_id,status').maybeSingle()
    if (error) throw error
    if (!data) throw err('not-found', 'Vendor complaint not found')
    const { error: notificationError } = await supabase.from('notifications')
      .update({ is_read: true })
      .eq('reference_id', complaintId)
      .eq('type', 'complaint')
    if (notificationError) throw notificationError
    const { error: auditError } = await supabase.from('admin_activity_logs').insert({
      admin_id: adminId,
      action_type: 'reviewed_complaint',
      target_id: complaintId,
      target_type: 'report',
      remarks: status,
    })
    if (auditError) throw auditError
    return { complaintId, status }
  }
  if (action === 'announcements') {
    return { announcements: await rows('system_announcements', '*', 'created_at') }
  }
  if (action === 'reports') {
    return { reports: await rows('reports', '*', 'created_at') }
  }

  if (action === 'update-report') {
    const reportId = requiredText(body, 'reportId')
    const status = requiredText(body, 'status')
    const changes: Json = {
      status,
      updated_at: new Date().toISOString(),
    }
    if ('notes' in body) changes.notes = body.notes ?? ''
    if ('decision' in body) changes.decision = body.decision ?? null
    if ('actionTaken' in body) changes.action_taken = body.actionTaken ?? null
    if ('resolutionNote' in body) changes.resolution_note = body.resolutionNote ?? null
    if (status === 'resolved') {
      changes.resolved_at = body.resolvedAt ?? new Date().toISOString()
      changes.resolved_by = body.resolvedBy ?? fullName ?? adminId
    }

    const { data, error } = await supabase.from('reports')
      .update(changes)
      .eq('id', reportId)
      .select('id,user_id,account_issue,resolution_note')
      .maybeSingle()
    if (error) throw error
    if (!data) throw err('not-found', 'Report not found')

    if (data.user_id && changes.resolution_note) {
      const { error: noticeError } = await supabase.from('notifications').insert({
        user_id: data.user_id,
        title: 'Report Update: ' + (changes.decision || 'Resolution Provided'),
        body: String(changes.resolution_note),
        type: 'system_announcement',
        reference_id: reportId,
      })
      if (noticeError) throw noticeError
    }

    const { error: auditError } = await supabase.from('admin_activity_logs').insert({
      admin_id: adminId,
      action_type: 'resolved_report',
      target_id: reportId,
      target_type: 'report',
      remarks: typeof changes.resolution_note === 'string' ? changes.resolution_note : 'Updated from admin portal',
    })
    if (auditError) console.error('Audit log failed:', auditError)

    return { reportId, status }
  }

  if (action === 'report-action') {
    const complaintId = requiredText(body, 'complaintId')
    const actionName = requiredText(body, 'actionName')
    if (!['warn', 'block_customer', 'suspend_vendor'].includes(actionName)) {
      throw err('invalid-argument', 'Unknown report action')
    }
    const { data: complaint, error: complaintError } = await supabase
      .from('vendor_complaints')
      .select('complaint_id,report_type,reporter_user_id,stall_holder_id,reason')
      .eq('complaint_id', complaintId)
      .maybeSingle()
    if (complaintError) throw complaintError
    if (!complaint) throw err('not-found', 'Report not found')

    let targetUserId = String(complaint.reporter_user_id)
    let targetRole: string | null = null
    if (complaint.report_type === 'vendor') {
      if (!complaint.stall_holder_id) throw err('failed-precondition', 'Report has no stall holder')
      const { data: stall, error } = await supabase.from('stall_holders')
        .select('user_id').eq('stall_holder_id', complaint.stall_holder_id).maybeSingle()
      if (error) throw error
      if (!stall?.user_id) throw err('not-found', 'Stall holder account not found')
      targetUserId = String(stall.user_id)
      targetRole = 'vendor'
    } else {
      const { data: reporter, error } = await supabase.from('users')
        .select('role').eq('user_id', targetUserId).maybeSingle()
      if (error) throw error
      targetRole = typeof reporter?.role === 'string' ? reporter.role : null
    }

    if (actionName === 'block_customer' &&
        (complaint.report_type !== 'support' || targetRole !== 'customer')) {
      throw err('failed-precondition', 'Only a customer account can be blocked from this report')
    }
    if (actionName === 'suspend_vendor' &&
        (complaint.report_type !== 'vendor' || targetRole !== 'vendor')) {
      throw err('failed-precondition', 'Only the reported stall holder can be suspended')
    }
    if (actionName !== 'warn' && targetUserId === uid) {
      throw err('failed-precondition', 'Admins cannot block or suspend themselves')
    }

    const isBlocked = actionName !== 'warn'
    if (isBlocked) {
      const { data, error } = await supabase.from('users').update({
        is_blocked: true,
        updated_at: new Date().toISOString(),
      }).eq('user_id', targetUserId).neq('role', 'admin').select('user_id').maybeSingle()
      if (error) throw error
      if (!data) throw err('not-found', 'Account not found or cannot be restricted')
      if (actionName === 'suspend_vendor') {
        const { error: stallError } = await supabase.from('stall_holders')
          .update({ is_blocked: true }).eq('stall_holder_id', complaint.stall_holder_id)
        if (stallError) throw stallError
      }
    }

    const title = actionName === 'warn'
      ? 'Official account warning'
      : actionName === 'block_customer' ? 'Account blocked' : 'Stall holder account suspended'
    const message = actionName === 'warn'
      ? `An administrator issued a warning about a report: ${complaint.reason}. Please review the app rules and contact support if you have questions.`
      : actionName === 'block_customer'
      ? 'An administrator blocked your account after reviewing a report. Contact support if you believe this is a mistake.'
      : 'An administrator suspended your stall holder account after reviewing a report. Contact support for more information.'
    const { error: notificationError } = await supabase.from('notifications').insert({
      user_id: targetUserId,
      title,
      body: message,
      type: 'account_action',
      reference_id: complaintId,
    })
    if (notificationError) throw notificationError
    const { error: auditError } = await supabase.from('admin_activity_logs').insert({
      admin_id: adminId,
      action_type: actionName === 'warn' ? 'warned_user'
        : actionName === 'block_customer' ? 'blocked_user' : 'suspended_vendor',
      target_id: targetUserId,
      target_type: actionName === 'suspend_vendor' ? 'stall_holder' : 'user',
      remarks: `Report ${complaintId}: ${actionName}`,
    })
    if (auditError) throw auditError
    return { complaintId, actionName, userId: targetUserId, blocked: isBlocked }
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
    if (error) {
      console.error('[admin-portal] publish-announcement insert failed:', error)
      throw err(
        'internal',
        `Could not save announcement (${error.code ?? 'database error'}): ${error.message}`,
      )
    }
    try {
      await recordAdminActivity(
        adminId,
        'published_announcement',
        String(data.announcement_id),
        'announcement',
        `Published announcement: ${String(data.title ?? '')}`,
      )
    } catch (auditError) {
      console.error('Could not record announcement publication:', auditError)
    }
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
    try {
      await recordAdminActivity(
        adminId,
        'updated_announcement',
        id,
        'announcement',
        `Updated announcement: ${changes.title}`,
      )
    } catch (auditError) {
      console.error('Could not record announcement update:', auditError)
    }
    return { id }
  }

  if (action === 'delete-announcement') {
    const id = requiredText(body, 'id')
    const { data, error } = await supabase.from('system_announcements')
      .delete().eq('announcement_id', id).select('announcement_id').maybeSingle()
    if (error) throw error
    if (!data) throw err('not-found', 'Announcement not found')
    try {
      await recordAdminActivity(
        adminId,
        'deleted_announcement',
        id,
        'announcement',
        'Deleted system announcement',
      )
    } catch (auditError) {
      console.error('Could not record announcement deletion:', auditError)
    }
    return { id }
  }

  throw err('invalid-argument', `Unknown action: ${action}`)
}))
