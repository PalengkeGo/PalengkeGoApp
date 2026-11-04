import { cert, getApps, initializeApp } from 'npm:firebase-admin@12.7.0/app'
import { getMessaging } from 'npm:firebase-admin@12.7.0/messaging'
import { supabase } from './backend.ts'

const channels: Record<string, string> = {
  new_message: 'palengkego_messages_sfx',
  incoming_order: 'palengkego_incoming_orders_sfx',
  order_completed: 'palengkego_completed_orders_sfx',
}

/** Best-effort FCM send. Push failures must never roll back a committed action. */
export async function sendPushToUsers(
  userIds: string[],
  title: string,
  body: string,
  type: string,
  referenceId?: string,
): Promise<void> {
  const recipients = [...new Set(userIds.filter(Boolean))]
  if (!recipients.length) return
  const serviceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
  if (!serviceAccount) {
    console.error('FIREBASE_SERVICE_ACCOUNT is not configured; push was not sent')
    return
  }
  try {
    if (!getApps().length) initializeApp({ credential: cert(JSON.parse(serviceAccount)) })
    const { data: devices, error } = await supabase.from('account_device_tokens')
      .select('user_id,token').in('user_id', recipients)
    if (error) throw error
    const rows = devices ?? []
    for (let offset = 0; offset < rows.length; offset += 500) {
      const batch = rows.slice(offset, offset + 500)
      const result = await getMessaging().sendEachForMulticast({
        tokens: batch.map((device) => String(device.token)),
        notification: { title, body },
        data: { type, title, body, ...(referenceId ? { reference_id: referenceId } : {}) },
        android: {
          priority: 'high',
          notification: { channelId: channels[type] ?? 'palengkego_account_updates' },
        },
        apns: { payload: { aps: { sound: 'default' } } },
      })
      const expired = batch.filter((_, index) => {
        const failure = result.responses[index]
        return !failure.success && [
          'messaging/registration-token-not-registered',
          'messaging/invalid-registration-token',
        ].includes(failure.error?.code ?? '')
      }).map((device) => String(device.token))
      if (expired.length) await supabase.from('account_device_tokens').delete().in('token', expired)
    }
  } catch (error) {
    console.error(`Could not send ${type} push:`, error)
  }
}

export async function sendPushToAdmins(title: string, body: string, type: string, referenceId?: string): Promise<void> {
  const { data, error } = await supabase.from('admins').select('user_id')
  if (error) {
    console.error('Could not load admin push recipients:', error)
    return
  }
  await sendPushToUsers((data ?? []).map((row) => String(row.user_id)), title, body, type, referenceId)
}
