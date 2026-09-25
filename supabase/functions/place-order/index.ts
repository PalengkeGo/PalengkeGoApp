import { bearerUid, err, handle, supabase } from '../_shared/backend.ts'
import { computeFees, FIELD_LIMITS, validateOptionalText } from '../_shared/constants.ts'

interface OrderItemInput {
  productId: string
  productName: string
  quantity: number
  unitPrice: number
  unit?: string
  image?: string
}

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req, false)

    const data = await req.json().catch(() => ({}))
    const lineItemsByStall: Record<string, OrderItemInput[]> = data.lineItemsByStall ?? {}
    const isPickup: boolean = data.isPickup === true
    const customerName: string = data.customerName ?? 'Customer'
    const deliveryAddress: string | null = data.deliveryAddress ?? null
    const deliveryLatitude: number | null = typeof data.deliveryLatitude === 'number' ? data.deliveryLatitude : null
    const deliveryLongitude: number | null = typeof data.deliveryLongitude === 'number' ? data.deliveryLongitude : null
    const isPriority: boolean = data.isPriority === true
    const priorityFee: number = typeof data.priorityFee === 'number' ? data.priorityFee : 0
    const paymentMethod: string = data.paymentMethod ?? 'cod'
    const vendorNotes: Record<string, string> = data.vendorNotes ?? {}

    // Find or create customer record
    let { data: customer } = await supabase
      .from('customers')
      .select('customer_id')
      .eq('user_id', uid)
      .maybeSingle()

    if (!customer) {
      const { data: newCustomer, error: custErr } = await supabase
        .from('customers')
        .insert({ user_id: uid, saved_address: deliveryAddress })
        .select('customer_id')
        .single()
      if (custErr || !newCustomer) {
        throw err('internal', 'Failed to resolve customer record')
      }
      customer = newCustomer
    }

    const createdOrders: any[] = []

    for (const [stallId, items] of Object.entries(lineItemsByStall)) {
      if (!Array.isArray(items) || items.length === 0) continue

      // Fetch stall info
      const { data: stall } = await supabase
        .from('stall_holders')
        .select('stall_holder_id, stall_name')
        .eq('stall_holder_id', stallId)
        .maybeSingle()

      const stallName = stall?.stall_name ?? 'Local Vendor'

      // Calculate totals
      let subtotal = 0
      for (const item of items) {
        const qty = item.quantity > 0 ? item.quantity : 1
        const price = item.unitPrice >= 0 ? item.unitPrice : 0
        subtotal += qty * price
      }

      const { deliveryFee, serviceFee, deliveryDistanceKm } = computeFees(
        isPickup ? 'pickup' : 'delivery',
        isPriority,
        deliveryLatitude,
        deliveryLongitude,
      )

      const totalAmount = subtotal + deliveryFee + (isPriority ? priorityFee : 0) + serviceFee

      // Create Order
      const { data: order, error: orderErr } = await supabase
        .from('orders')
        .insert({
          customer_id: customer.customer_id,
          stall_holder_id: stall?.stall_holder_id ?? stallId,
          fulfillment_type: isPickup ? 'pickup' : 'delivery',
          delivery_address: deliveryAddress,
          delivery_latitude: deliveryLatitude,
          delivery_longitude: deliveryLongitude,
          distance_km: deliveryDistanceKm ?? 0,
          delivery_fee: deliveryFee,
          subtotal: subtotal,
          total_amount: totalAmount,
          payment_method: paymentMethod,
          payment_status: 'pending',
          order_status: 'pending',
        })
        .select('order_id, created_at')
        .single()

      if (orderErr || !order) {
        console.error('Order creation error:', orderErr)
        throw err('internal', 'Failed to create order record')
      }

      // Insert Order Items
      const orderItems = items.map((item) => ({
        order_id: order.order_id,
        product_id: item.productId,
        product_name: item.productName || 'Product',
        category_tag: 'Vegetables',
        quantity: Math.max(1, Math.round(item.quantity)),
        price_at_order: item.unitPrice,
        subtotal: item.quantity * item.unitPrice,
      }))

      await supabase.from('order_items').insert(orderItems)

      // Audit History
      await supabase.from('order_status_history').insert({
        order_id: order.order_id,
        previous_status: null,
        new_status: 'pending',
        changed_by: uid,
        remarks: vendorNotes[stallId] ?? 'Order placed',
      })

      createdOrders.push({
        id: order.order_id,
        customerUid: uid,
        stallId: stallId,
        vendorName: stallName,
        vendorImage: '',
        customerName: customerName,
        status: 'pending',
        paymentStatus: 'pending',
        paymentMethod: paymentMethod,
        fulfillmentMethod: isPickup ? 'pickup' : 'delivery',
        placedAt: order.created_at || new Date().toISOString(),
        items: items.map((i) => ({
          productId: i.productId,
          productName: i.productName,
          quantity: i.quantity,
          unitPrice: i.unitPrice,
          unit: i.unit || 'kg',
          image: i.image || '',
        })),
        deliveryAddress: deliveryAddress,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
        deliveryDistanceKm: deliveryDistanceKm,
        deliveryFee: deliveryFee,
        serviceFee: serviceFee,
        isPriority: isPriority,
        priorityFee: priorityFee,
        notes: vendorNotes[stallId] ?? null,
      })
    }

    return { orders: createdOrders }
  }),
)
