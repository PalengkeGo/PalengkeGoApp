import { assertRole, bearerUid, err, handle, roleOf, supabase } from '../_shared/backend.ts'
import { rateLimit } from '../_shared/security.ts'

type Json = Record<string, unknown>

function text(body: Json, key: string, max: number): string {
  const value = body[key]
  if (typeof value !== 'string' || !value.trim() || value.length > max) {
    throw err('invalid-argument', `${key} is required and must be at most ${max} characters`)
  }
  return value.trim()
}

function conversationId(body: Json): string {
  const value = text(body, 'conversationId', 36)
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) {
    throw err('invalid-argument', 'conversationId must be a valid UUID')
  }
  return value
}

function throwDatabaseError(error: { code?: string }): never {
  if (error.code === '42501') throw err('permission-denied', 'Support conversation access denied')
  if (error.code === '22023') throw err('invalid-argument', 'Support message or conversation is invalid')
  if (error.code === 'P0002') throw err('not-found', 'Support conversation not found')
  throw err('internal', 'Could not complete the support messaging request')
}

async function requireAdmin(uid: string): Promise<string> {
  const { data, error } = await supabase.from('admins').select('admin_id')
    .eq('user_id', uid).maybeSingle()
  if (error) throw error
  if (!data) throw err('permission-denied', 'Administrator account is not registered')
  return String(data.admin_id)
}

async function auditAdminAction(
  adminId: string,
  actionType: string,
  conversationId: string,
  remarks: string,
): Promise<void> {
  const { error } = await supabase.from('admin_activity_logs').insert({
    admin_id: adminId,
    action_type: actionType,
    target_id: conversationId,
    target_type: 'support_conversation',
    remarks,
  })
  if (error) console.error('Could not record support chat audit entry:', error)
}

Deno.serve((request: Request) => handle(request, async (req) => {
  if (req.method !== 'POST') throw err('invalid-argument', 'POST required')
  const uid = await bearerUid(req)
  const role = await roleOf(uid)
  assertRole(role, ['admin', 'customer', 'vendor', 'stallholder'])
  const actorRole = role === 'stallholder' ? 'vendor' : role as 'admin' | 'customer' | 'vendor'
  const adminId = actorRole === 'admin' ? await requireAdmin(uid) : null
  const body = await req.json() as Json
  const action = text(body, 'action', 40)

  if (action === 'list-conversations') {
    let query = supabase.from('support_conversations').select('*')
      .order('updated_at', { ascending: false }).limit(role === 'admin' ? 200 : 100)
    if (actorRole !== 'admin') query = query.eq('user_id', uid)
    if (body.status === 'open' || body.status === 'closed') query = query.eq('status', body.status)
    const { data, error } = await query
    if (error) throw error
    const userIds = [...new Set((data ?? []).map((row) => String(row.user_id)))]
    const { data: users, error: usersError } = userIds.length
      ? await supabase.from('users').select('user_id,full_name,email').in('user_id', userIds)
      : { data: [], error: null }
    if (usersError) throw usersError
    const userById = new Map((users ?? []).map((user) => [String(user.user_id), user]))
    return { conversations: (data ?? []).map((row) => ({
      ...row,
      user_name: userById.get(String(row.user_id))?.full_name ?? 'User',
      user_email: userById.get(String(row.user_id))?.email ?? '',
    })) }
  }

  if (action === 'start-conversation') {
    if (actorRole === 'admin') throw err('permission-denied', 'Only customers and stall holders can start a support conversation')
    const subject = text(body, 'subject', 120)
    const firstMessage = text(body, 'message', 4000)
    await rateLimit(uid, 'support-chat-start', 5)
    const { data, error } = await supabase.rpc('support_start_conversation', {
      p_user_id: uid, p_user_role: actorRole, p_subject: subject, p_body: firstMessage,
    }).single()
    if (error) throwDatabaseError(error)
    return { conversation: data }
  }

  if (action === 'messages') {
    const id = conversationId(body)
    let query = supabase.from('support_conversations').select('id,user_id,user_role,status')
      .eq('id', id)
    if (actorRole !== 'admin') query = query.eq('user_id', uid).eq('user_role', actorRole)
    const { data: conversation, error: conversationError } = await query.maybeSingle()
    if (conversationError) throw conversationError
    if (!conversation) throw err('not-found', 'Support conversation not found')
    const { data, error } = await supabase.from('support_messages').select('*')
      .eq('conversation_id', id).order('created_at', { ascending: true }).limit(500)
    if (error) throw error
    return { messages: data ?? [] }
  }

  if (action === 'send-message') {
    const id = conversationId(body)
    const message = text(body, 'message', 4000)
    await rateLimit(uid, 'support-chat-send', 30)
    const { data, error } = await supabase.rpc('support_send_message', {
      p_conversation_id: id, p_sender_user_id: uid, p_sender_role: actorRole, p_body: message,
    }).single()
    if (error) throwDatabaseError(error)
    if (adminId) await auditAdminAction(adminId, 'support_message_sent', id, 'Administrator replied to a support conversation')
    return { message: data }
  }

  if (action === 'mark-read') {
    const id = conversationId(body)
    const { error } = await supabase.rpc('support_mark_read', {
      p_conversation_id: id, p_reader_user_id: uid, p_reader_role: actorRole,
    })
    if (error) throwDatabaseError(error)
    return { conversationId: id, read: true }
  }

  if (action === 'close-conversation') {
    if (actorRole !== 'admin' || !adminId) throw err('permission-denied', 'Only administrators can close support conversations')
    const id = conversationId(body)
    const { data, error } = await supabase.from('support_conversations')
      .update({ status: 'closed', updated_at: new Date().toISOString() })
      .eq('id', id).select('id').maybeSingle()
    if (error) throw error
    if (!data) throw err('not-found', 'Support conversation not found')
    await auditAdminAction(adminId, 'support_conversation_closed', id, 'Closed support conversation')
    return { conversationId: id, status: 'closed' }
  }

  throw err('invalid-argument', `Unknown action: ${action}`)
}))
