import { bearerUid, err, handle, isBlocked, supabase } from '../_shared/backend.ts'
Deno.serve((req: Request) => handle(req, async (req) => {
  const uid=await bearerUid(req)
  if(await isBlocked(uid)) throw err('permission-denied','Your account is blocked')
  const data=await req.json()
  const vendor=data.vendor===true
  const {data: identities,error: identityError}=await supabase.from(vendor?'stall_holders':'customers')
    .select(vendor?'stall_holder_id':'customer_id').eq('user_id',uid)
  if(identityError) throw err('internal','Unable to load account')
  const ids=[uid,...(identities??[]).map((row: any)=>vendor?row.stall_holder_id:row.customer_id)]
  const {data: orders,error}=await supabase.from('orders').select('*, items:order_items(*)')
    .in(vendor?'stall_holder_id':'customer_id',ids).order('created_at',{ascending:false})
  if(error) throw err('internal','Unable to load orders')
  if(!orders?.length) return {orders:[]}
  const {data: stalls,error: stallsError}=await supabase.from('stall_holders')
    .select('stall_holder_id,stall_name,banner_image_url,thumbnail_url').in('stall_holder_id',orders.map((o)=>o.stall_holder_id))
  if(stallsError) throw err('internal','Unable to load stalls')
  const byId=new Map((stalls??[]).map((stall)=>[stall.stall_holder_id,stall]))
  // Orders store customer profile IDs; chat requires the customer's Firebase UID.
  const customerUids = new Map<string, string>()
  if (vendor) {
    const {data: customers, error: customersError} = await supabase.from('customers')
      .select('customer_id,user_id').in('customer_id', orders.map((order)=>order.customer_id))
    if (customersError) throw err('internal','Unable to load order customers')
    for (const customer of customers ?? []) customerUids.set(customer.customer_id, customer.user_id)
  }
  return {orders:orders.map((order)=>({...order,stall:byId.get(order.stall_holder_id),
    customer_uid:vendor ? customerUids.get(order.customer_id) ?? order.customer_id : uid}))}
}))
