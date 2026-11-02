import { assertRole, bearerUid, err, handle, roleOf, supabase } from '../_shared/backend.ts'
import { rateLimit } from '../_shared/security.ts'

type Json = Record<string, unknown>
const conversationFields = 'id,user_id,user_role,subject,status,last_message,last_message_at,user_unread_count,admin_unread_count,created_at,updated_at'
const messageFields = 'id,conversation_id,sender_user_id,sender_role,body,attachment_path,created_at,read_at'
function text(body: Json, key: string, max: number): string {
  const value = body[key]
  if (typeof value !== 'string' || !value.trim() || value.length > max) throw err('invalid-argument', `${key} is required (maximum ${max} characters)`)
  return value.trim()
}
function uuid(value: unknown): string {
  if (typeof value !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) throw err('invalid-argument', 'Invalid conversation or cursor ID')
  return value
}
function cursor(value: unknown): { at: string; id: string } | null {
  if (value == null) return null
  if (typeof value !== 'object') throw err('invalid-argument', 'Invalid cursor')
  const c = value as Json
  if (typeof c.at !== 'string' || !/^\d{4}-\d{2}-\d{2}T[0-9:.]+(?:Z|[+-]\d{2}:\d{2})$/.test(c.at) || !Number.isFinite(Date.parse(c.at))) throw err('invalid-argument', 'Invalid cursor timestamp')
  return { at: c.at, id: uuid(c.id) }
}
function dbError(error: { code?: string }): never {
  if (error.code === '42501') throw err('permission-denied', 'Support chat access denied')
  if (error.code === '22023') throw err('invalid-argument', 'Invalid support message')
  throw err('internal', 'Could not complete the support request')
}
async function signedMessages(rows: any[]): Promise<any[]> {
  return await Promise.all(rows.map(async (row) => {
    if (!row.attachment_path) return row
    const { data, error } = await supabase.storage.from('support-attachments').createSignedUrl(row.attachment_path, 3600)
    if (error) throw err('internal', 'Could not load the attached photo')
    return { ...row, attachment_url: data.signedUrl }
  }))
}
Deno.serve((request: Request) => handle(request, async (req) => {
  if (req.method !== 'POST') throw err('invalid-argument', 'POST required')
  const uid = await bearerUid(req)
  const role = await roleOf(uid)
  assertRole(role, ['admin', 'vendor', 'stallholder'])
  const actorRole = role === 'admin' ? 'admin' : 'vendor'
  const { data: allowed, error: accessError } = await supabase.rpc('support_actor', { p_uid: uid, p_role: actorRole })
  if (accessError) throw accessError
  if (!allowed) throw err('permission-denied', 'Only approved stall holders and registered administrators can use this chat')
  const body = await req.json() as Json
  const action = text(body, 'action', 40)
  const before = cursor(body.before)
  const after = cursor(body.after)
  if (before && after) throw err('invalid-argument', 'Use one cursor at a time')
  if (action === 'list-conversations') {
    let query = supabase.from('support_conversations').select(conversationFields)
      .eq('user_role', 'vendor').order('updated_at', { ascending: false }).order('id', { ascending: false }).limit(51)
    if (actorRole !== 'admin') query = query.eq('user_id', uid)
    if (before) query = query.or(`updated_at.lt.${before.at},and(updated_at.eq.${before.at},id.lt.${before.id})`)
    const { data, error } = await query
    if (error) throw error
    const page = (data ?? []).slice(0, 50)
    const userIds = [...new Set(page.map((row) => row.user_id))]
    const { data: stalls, error: stallsError } = userIds.length
      ? await supabase.from('stall_holders').select('user_id,stall_holder_id,stall_name').in('user_id', userIds)
      : { data: [], error: null }
    if (stallsError) throw stallsError
    const byUser = new Map((stalls ?? []).map((s) => [s.user_id, s]))
    const last = page.at(-1)
    const supportConversations = page.map((row) => ({
      ...row,
      conversation_type: 'support',
      stall: byUser.get(row.user_id),
    }))
    let directConversations: any[] = []
    if (actorRole === 'admin') {
      const { data: directRows, error: directError } = await supabase
        .from('conversations')
        .select('id,stall_id,stall_name,customer_uid,customer_name,inquiry_type,related_order_id,last_message_text,last_message_timestamp,last_message_sender_id,customer_unread_count,vendor_unread_count,created_at,updated_at')
        .eq('customer_uid', uid)
        .order('updated_at', { ascending: false })
        .limit(100)
      if (directError) throw directError
      directConversations = (directRows ?? []).map((row) => ({
        id: String(row.id),
        conversation_type: 'direct',
        user_role: 'vendor',
        user_id: String(row.stall_id),
        subject: String(row.inquiry_type ?? 'Product inquiry'),
        status: 'open',
        last_message: String(row.last_message_text ?? ''),
        last_message_at: row.last_message_timestamp,
        user_unread_count: row.vendor_unread_count ?? 0,
        admin_unread_count: row.customer_unread_count ?? 0,
        created_at: row.created_at,
        updated_at: row.updated_at,
        stall: { stall_holder_id: row.stall_id, stall_name: row.stall_name },
        direct_customer_name: row.customer_name,
        related_order_id: row.related_order_id,
      }))
    }
    const conversations = [...supportConversations, ...directConversations]
      .sort((a, b) => Date.parse(String(b.updated_at)) - Date.parse(String(a.updated_at)))
      .slice(0, 100)
    return { conversations,
      nextCursor: data && data.length > 50 && last ? { at: last.updated_at, id: last.id } : null }
  }
  if (action === 'start-conversation') {
    if (actorRole !== 'vendor') throw err('permission-denied', 'Only stall holders can start conversations')
    await rateLimit(uid, 'support-chat-start', 5)
    const { data, error } = await supabase.rpc('support_start_conversation', {
      p_user_id: uid, p_user_role: actorRole, p_subject: text(body, 'subject', 120), p_body: text(body, 'message', 4000),
    }).single()
    if (error) dbError(error)
    return { conversation: data }
  }
  const id = uuid(body.conversationId)
  if (body.conversationType === 'direct') {
    if (actorRole !== 'admin') throw err('permission-denied', 'Only administrators can access direct admin conversations')
    const { data: directConversation, error: directConversationError } = await supabase
      .from('conversations')
      .select('id,customer_uid,stall_id,stall_name,customer_name,inquiry_type')
      .eq('id', id)
      .eq('customer_uid', uid)
      .maybeSingle()
    if (directConversationError) throw directConversationError
    if (!directConversation) throw err('not-found', 'Admin conversation not found')

    const signedDirectMessages = async (items: any[]) => await Promise.all(items.map(async (row) => {
      let attachmentUrl = typeof row.attachment_url === 'string' ? row.attachment_url : null
      if (attachmentUrl?.startsWith('chat-attachments/')) {
        const { data, error } = await supabase.storage.from('chat-attachments')
          .createSignedUrl(attachmentUrl.slice('chat-attachments/'.length), 3600)
        if (error) throw err('internal', 'Could not load the attached photo')
        attachmentUrl = data.signedUrl
      }
      return {
        id: row.id,
        conversation_id: `direct:${row.conversation_id}`,
        sender_user_id: row.sender_id,
        sender_role: row.sender_role,
        sender_name: row.sender_name,
        body: row.text ?? '',
        created_at: row.timestamp,
        read_at: row.read_at,
        attachment_url: attachmentUrl,
      }
    }))

    if (action === 'messages') {
      let query = supabase.from('messages').select('id,conversation_id,sender_id,sender_role,sender_name,text,timestamp,is_read,read_at,attachment_url,attachment_type')
        .eq('conversation_id', id)
        .order('timestamp', { ascending: after != null })
        .order('id', { ascending: after != null })
        .limit(51)
      if (before) query = query.or(`timestamp.lt.${before.at},and(timestamp.eq.${before.at},id.lt.${before.id})`)
      if (after) query = query.or(`timestamp.gt.${after.at},and(timestamp.eq.${after.at},id.gt.${after.id})`)
      const { data, error } = await query
      if (error) throw error
      const page = (data ?? []).slice(0, 50)
      const last = page.at(-1)
      return {
        messages: await signedDirectMessages(after ? page : page.reverse()),
        status: 'open',
        nextCursor: data && data.length > 50 && last ? { at: last.timestamp, id: last.id } : null,
      }
    }
    if (action === 'mark-read') {
      const { error } = await supabase.rpc('admin_direct_chat_mark_read', {
        p_conversation_id: id,
        p_actor: uid,
      })
      if (error) dbError(error)
      return { read: true }
    }
    if (action === 'upload-photo') {
      const mime = text(body, 'mime', 30)
      const ext = ({ 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/gif': 'gif' } as Record<string, string>)[mime]
      if (!ext) throw err('invalid-argument', 'Choose a JPEG, PNG, WebP or GIF image')
      await rateLimit(uid, 'support-chat-upload', 10)
      const path = `${id}/${uid}/${crypto.randomUUID()}.${ext}`
      const { data, error } = await supabase.storage.from('chat-attachments').createSignedUploadUrl(path)
      if (error) throw error
      return { path, token: data.token, bucket: 'chat-attachments' }
    }
    if (action === 'send-message') {
      const message = typeof body.message === 'string' ? body.message.trim() : ''
      const path = body.attachmentPath
      if (message.length > 10000 || (!message && !path)) throw err('invalid-argument', 'Enter a message or attach a photo')
      if (path != null && (typeof path !== 'string' || !path.startsWith(`${id}/${uid}/`) || path.includes('..'))) throw err('invalid-argument', 'Invalid photo path')
      await rateLimit(uid, 'support-chat-send', 30)
      const attachmentUrl = typeof path === 'string' ? `chat-attachments/${path}` : null
      const { data, error } = await supabase.rpc('admin_direct_chat_send', {
        p_conversation_id: id,
        p_actor: uid,
        p_body: message,
        p_attachment_url: attachmentUrl,
      }).single()
      if (error) dbError(error)
      const { data: admin } = await supabase.from('admins').select('admin_id').eq('user_id', uid).maybeSingle()
      if (admin?.admin_id) await supabase.from('admin_activity_logs').insert({
        admin_id: admin.admin_id,
        action_type: 'support_message_sent',
        target_id: id,
        target_type: 'support_conversation',
        remarks: 'Administrator replied to vendor direct conversation',
      })
      return { message: (await signedDirectMessages([data]))[0] }
    }
    throw err('invalid-argument', 'Unknown direct conversation action')
  }
  let access = supabase.from('support_conversations').select('id,user_id,status').eq('id', id).eq('user_role', 'vendor')
  if (actorRole !== 'admin') access = access.eq('user_id', uid)
  const { data: conversation, error: conversationError } = await access.maybeSingle()
  if (conversationError) throw conversationError
  if (!conversation) throw err('not-found', 'Support conversation not found')
  if (action === 'messages') {
    let query = supabase.from('support_messages').select(messageFields).eq('conversation_id', id)
      .order('created_at', { ascending: after != null }).order('id', { ascending: after != null }).limit(51)
    if (before) query = query.or(`created_at.lt.${before.at},and(created_at.eq.${before.at},id.lt.${before.id})`)
    if (after) query = query.or(`created_at.gt.${after.at},and(created_at.eq.${after.at},id.gt.${after.id})`)
    const { data, error } = await query
    if (error) throw error
    const page = (data ?? []).slice(0, 50)
    const last = page.at(-1)
    return { messages: await signedMessages(after ? page : page.reverse()), status: conversation.status,
      nextCursor: data && data.length > 50 && last ? { at: last.created_at, id: last.id } : null }
  }
  if (action === 'mark-read') {
    const { error } = await supabase.rpc('support_mark_read', { p_conversation_id: id, p_reader_user_id: uid, p_reader_role: actorRole })
    if (error) dbError(error)
    return { read: true }
  }
  if (conversation.status !== 'open') throw err('failed-precondition', 'This conversation is closed. Start a new conversation for further help.')
  if (action === 'upload-photo') {
    const mime = text(body, 'mime', 30)
    const ext = ({ 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/gif': 'gif' } as Record<string, string>)[mime]
    if (!ext) throw err('invalid-argument', 'Choose a JPEG, PNG, WebP or GIF image')
    await rateLimit(uid, 'support-chat-upload', 10)
    const path = `${id}/${uid}/${crypto.randomUUID()}.${ext}`
    const { data, error } = await supabase.storage.from('support-attachments').createSignedUploadUrl(path)
    if (error) throw error
    return { path, token: data.token }
  }
  if (action === 'send-message') {
    const message = typeof body.message === 'string' ? body.message.trim() : ''
    const path = body.attachmentPath
    if (message.length > 4000 || (!message && !path)) throw err('invalid-argument', 'Enter a message or attach a photo (maximum 4000 characters)')
    if (path != null && (typeof path !== 'string' || !path.startsWith(`${id}/${uid}/`) || path.includes('..'))) throw err('invalid-argument', 'Invalid photo path')
    await rateLimit(uid, 'support-chat-send', 30)
    const args = { p_conversation_id: id, p_sender_user_id: uid, p_sender_role: actorRole, p_body: message }
    const { data, error } = path
      ? await supabase.rpc('support_send_photo', { ...args, p_attachment_path: path }).single()
      : await supabase.rpc('support_send_message', args).single()
    if (error) dbError(error)
    if (actorRole === 'admin') {
      const { data: admin } = await supabase.from('admins').select('admin_id').eq('user_id', uid).single()
      const { error: auditError } = await supabase.from('admin_activity_logs').insert({ admin_id: admin?.admin_id,
        action_type: 'support_message_sent', target_id: id, target_type: 'support_conversation', remarks: 'Administrator replied to stall holder' })
      if (auditError) console.error('Support audit failed', auditError.code)
    }
    return { message: data }
  }
  throw err('invalid-argument', 'Unknown support action')
}))
