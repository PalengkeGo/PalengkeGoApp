// Run: npx --yes --package=deno deno test --allow-read --allow-env supabase/tests/app_connections_test.ts
// Isolated PostgreSQL engine: never connects to or mutates the live project.
import { PGlite } from 'npm:@electric-sql/pglite@0.3.14'
import { strict as assert } from 'node:assert'

Deno.test('database saves, checkout rollback, status transitions and review totals', async () => {
  const db = new PGlite()
  try {
    await db.exec('CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;')
    for (const name of ['20260924000000_core_tables.sql', '20260925000000_fix_users_rls_and_role.sql',
      '20260925010000_convert_ids_to_text.sql', '20260926020000_products_text_id_and_rls.sql',
      '20260927000000_stall_holders_branding_columns.sql']) {
      await db.exec(await Deno.readTextFile(new URL('../migrations/'+name, import.meta.url)))
    }
    // Match the live schema: ratings.order_id was separately converted to text.
    await db.exec('ALTER TABLE ratings DROP CONSTRAINT ratings_order_id_fkey; ALTER TABLE ratings ALTER COLUMN order_id TYPE text;')
    await db.exec(await Deno.readTextFile(new URL('../migrations/20260928010000_orders_details_and_rls.sql', import.meta.url)))
    await db.exec('ALTER TABLE ratings ADD FOREIGN KEY(order_id) REFERENCES orders(order_id);')
    await db.exec(await Deno.readTextFile(new URL('../migrations/20260930010000_app_data_connections.sql', import.meta.url)))
    await db.exec(`INSERT INTO users(user_id,full_name,email,role) VALUES
      ('customer','Customer','customer@test.invalid','customer'),('vendor','Vendor','vendor@test.invalid','vendor');
      INSERT INTO stall_holders(stall_holder_id,user_id,stall_name,stall_number,floor_number,category,is_open)
      VALUES('stall','vendor','Fruit Stall','1','1','Fruits',true);
      INSERT INTO products(product_id,stall_holder_id,product_name,category_tag,unit,price_per_kg,stock_quantity)
      VALUES('product','stall','Mango','Fruits','kg',100,5);`)
    const checkout = {lineItemsByStall: {stall: [{productId: 'product',quantity: 1.5}]},
      isPickup: true, paymentMethod: 'cod', customerName: 'Customer',customerPhone: '09123456789',
      vendorNotes: {stall: 'Ripe please'}, fees: {serviceFee:0,deliveryFee:0,priorityFee:0}}
    const place = (body: unknown) => db.query<{result: Record<string, any>[]}>(
      'SELECT place_market_orders($1,$2::jsonb) AS result',['customer', JSON.stringify(body)])
    const placed = (await place(checkout)).rows[0].result[0]
    assert.equal(placed.subtotal,150)
    assert.equal(placed.customer_phone,'09123456789')
    assert.equal(placed.notes,'Ripe please')
    assert.equal(placed.items[0].quantity,1.5)
    assert.equal((await db.query<{stock_quantity:number}>('SELECT stock_quantity FROM products')).rows[0].stock_quantity,3.5)
    await assert.rejects(place({...checkout,lineItemsByStall:{stall:[{productId:'product',quantity:9}]}}))
    assert.equal((await db.query('SELECT * FROM orders')).rows.length,1)
    assert.equal((await db.query<{stock_quantity:number}>('SELECT stock_quantity FROM products')).rows[0].stock_quantity,3.5)
    await assert.rejects(db.query('SELECT transition_market_order($1,$2,$3)',['customer',placed.order_id,'preparing']))
    for (const status of ['preparing','ready','delivered']) {
      await db.query('SELECT transition_market_order($1,$2,$3)',['vendor',placed.order_id,status])
    }
    const completed = (await db.query<{order_status:string,payment_status:string}>('SELECT * FROM orders')).rows[0]
    assert.equal(completed.order_status,'delivered')
    assert.equal(completed.payment_status,'paid')
    await assert.rejects(db.query('SELECT transition_market_order($1,$2,$3)',['vendor',placed.order_id,'preparing']))
    await db.query(`INSERT INTO ratings(customer_id,stall_holder_id,order_id,score) VALUES($1,'stall',$2,4)`,[placed.customer_id,placed.order_id])
    assert.equal((await db.query<{average_rating:number}>('SELECT average_rating FROM stall_holders')).rows[0].average_rating,4)
    const settings={stall_name:'Updated Stall',description:'Updated',category:'Fruits',is_open:true,
      schedule:[{name:'Monday',isOpen:true,openTime:'07:00',closeTime:'17:00'}]}
    await db.query('SELECT save_market_stall($1,$2::jsonb)',['vendor',JSON.stringify(settings)])
    assert.equal((await db.query('SELECT * FROM stall_holder_schedule')).rows.length,1)
    await assert.rejects(db.query('SELECT save_market_stall($1,$2::jsonb)', ['vendor',JSON.stringify({...settings,
      stall_name:'Must roll back',schedule:[{name:'Bad day',isOpen:true,openTime:'07:00',closeTime:'17:00'}]})]))
    assert.equal((await db.query<{stall_name:string}>('SELECT stall_name FROM stall_holders')).rows[0].stall_name,'Updated Stall')
    const cancelId=(await place(checkout)).rows[0].result[0].order_id
    await db.query('SELECT transition_market_order($1,$2,$3,NULL,NULL,true)',['customer',cancelId,'cancelled'])
    assert.equal((await db.query<{stock_quantity:number}>('SELECT stock_quantity FROM products')).rows[0].stock_quantity,3.5)
    const address={label:'Home',fullAddress:'Test street',latitude:13.62,longitude:123.18,contactName:'Customer'}
    const savedAddress=(await db.query<{address: {address_id:string}}>(
      'SELECT save_customer_address($1,$2::jsonb) AS address',['customer',JSON.stringify(address)])).rows[0].address
    assert.ok(savedAddress.address_id)
    await assert.rejects(db.query('SELECT save_customer_address($1,$2::jsonb,true)',
      ['vendor',JSON.stringify({...address,addressId:savedAddress.address_id})]))
    await db.query('SELECT save_customer_address($1,$2::jsonb,true)',
      ['customer',JSON.stringify({...address,addressId:savedAddress.address_id})])
    assert.equal((await db.query('SELECT * FROM customer_addresses')).rows.length,0)
    await db.query('SELECT refund_market_order($1,$2,$3)',['customer',placed.order_id,'request'])
    assert.equal((await db.query<{payment_status:string}>('SELECT payment_status FROM orders WHERE order_id=$1',[placed.order_id])).rows[0].payment_status,'refundRequested')
    await db.query('SELECT refund_market_order($1,$2,$3)',['vendor',placed.order_id,'decline'])
    assert.equal((await db.query<{payment_status:string}>('SELECT payment_status FROM orders WHERE order_id=$1',[placed.order_id])).rows[0].payment_status,'paid')
    const permissions = await db.query<{allowed:boolean}>(`SELECT has_function_privilege('anon','place_market_orders(text,jsonb)','EXECUTE') AS allowed`)
    assert.equal(permissions.rows[0].allowed,false)
  } finally {
    await db.close()
  }
})
