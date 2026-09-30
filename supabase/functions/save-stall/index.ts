import { bearerUid, err, handle, isBlocked, supabase } from '../_shared/backend.ts'

Deno.serve((req: Request) => handle(req, async (req) => {
  const uid = await bearerUid(req)
  if (await isBlocked(uid)) throw err('permission-denied', 'Your account is blocked')
  const data = await req.json()
  if (typeof data.stall_name !== 'string' || !data.stall_name.trim() || data.stall_name.length > 100 ||
    typeof data.description !== 'string' || data.description.length > 2000 ||
    typeof data.category !== 'string' || typeof data.is_open !== 'boolean') {
    throw err('invalid-argument', 'Invalid stall details')
  }
  if (data.schedule !== undefined && (!Array.isArray(data.schedule) || data.schedule.length > 7 ||
    new Set(data.schedule.map((day: {name: string}) => day.name)).size !== data.schedule.length)) {
    throw err('invalid-argument', 'Invalid operating schedule')
  }
  const { data: stall, error } = await supabase.rpc('save_market_stall', {p_uid: uid, p_data: data})
  if (error) throw err('failed-precondition', 'Stall settings could not be saved. Check your stall registration and operating hours.')
  return {stall}
}))
