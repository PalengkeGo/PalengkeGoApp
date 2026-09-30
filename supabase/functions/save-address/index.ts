import { bearerUid, err, handle, supabase } from '../_shared/backend.ts'
Deno.serve((req: Request) => handle(req, async (req) => {
  const uid = await bearerUid(req)
  const data = await req.json()
  if (data.read === true) {
    const {data:customers,error:customerError}=await supabase.from('customers').select('customer_id').eq('user_id',uid)
    if(customerError) throw err('internal','Unable to load account')
    if(!customers?.length) return {addresses:[]}
    const {data:addresses,error}=await supabase.from('customer_addresses').select().in('customer_id',customers.map((c)=>c.customer_id))
    if(error) throw err('internal','Unable to load addresses')
    return {addresses}
  }
  const address = data.address
  if (!address || typeof address !== 'object') throw err('invalid-argument', 'Address required')
  if (data.delete !== true && (typeof address.fullAddress !== 'string' || !address.fullAddress.trim() ||
    address.fullAddress.length > 500 || typeof address.label !== 'string' || !address.label.trim() || address.label.length > 50)) {
    throw err('invalid-argument', 'Invalid address')
  }
  for (const field of ['latitude','longitude']) {
    const value=address[field]
    if (value != null && (typeof value !== 'number' || !Number.isFinite(value) ||
      Math.abs(value) > (field === 'latitude' ? 90 : 180))) throw err('invalid-argument','Invalid coordinates')
  }
  const {data: saved,error}=await supabase.rpc('save_customer_address', {
    p_uid:uid,p_address:address,p_delete:data.delete===true,
  })
  if(error) throw err('failed-precondition','Address could not be saved. Please try again.')
  return {address:saved}
}))
