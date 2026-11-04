import { bearerUid, err, handle, supabase } from '../_shared/backend.ts'
import { rateLimit } from '../_shared/security.ts'
import { sendPushToUsers } from '../_shared/push.ts'

Deno.serve((req: Request) => handle(req, async (request) => {
  if (request.method !== 'POST') throw err('invalid-argument', 'POST required')
  const uid = await bearerUid(request)
  await rateLimit(uid, 'notify-chat-message', 60)
  const body = await request.json() as Record<string, unknown>
  if (typeof body.conversationId !== 'string' || !body.conversationId ||
      typeof body.messageId !== 'string' || !body.messageId) {
    throw err('invalid-argument', 'Conversation and message IDs are required')
  }

  const { data: message, error: messageError } = await supabase.from('messages')
    .select('id,conversation_id,sender_id,sender_name,text,attachment_url,timestamp')
    .eq('id', body.messageId).eq('conversation_id', body.conversationId)
    .eq('sender_id', uid).maybeSingle()
  if (messageError) throw messageError
  if (!message || Date.now() - Date.parse(String(message.timestamp)) > 120_000) {
    throw err('permission-denied', 'Only a recently sent message can trigger a notification')
  }

  const { data: conversation, error: conversationError } = await supabase.from('conversations')
    .select('id,stall_id,stall_name,customer_uid,customer_name')
    .eq('id', body.conversationId).maybeSingle()
  if (conversationError) throw conversationError
  if (!conversation) throw err('not-found', 'Conversation not found')
  const { data: stall, error: stallError } = await supabase.from('stall_holders')
    .select('user_id').eq('stall_holder_id', conversation.stall_id).maybeSingle()
  if (stallError) throw stallError
  if (!stall?.user_id) throw err('not-found', 'Stall holder account not found')

  const recipient = uid === String(conversation.customer_uid)
    ? String(stall.user_id)
    : uid === String(stall.user_id) ? String(conversation.customer_uid) : null
  if (!recipient) throw err('permission-denied', 'Chat access denied')
  const preview = String(message.text ?? '').trim() || (message.attachment_url ? 'You received a photo.' : 'New message')
  await sendPushToUsers(
    [recipient],
    `New message from ${String(message.sender_name ?? 'PalengkeGo user')}`,
    preview.slice(0, 180),
    'new_message',
    String(conversation.id),
  )
  return { notified: true }
}))
