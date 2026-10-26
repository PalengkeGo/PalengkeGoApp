import { PGlite } from 'npm:@electric-sql/pglite@0.3.14'
import { strict as assert } from 'node:assert'

Deno.test('account moderation is atomic, private, authorized, and time bounded', async () => {
  const db = new PGlite()
  try {
    await db.exec(`
      CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
      CREATE SCHEMA auth;
      CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
      CREATE TABLE users(user_id text PRIMARY KEY, role text, is_blocked boolean DEFAULT false, updated_at timestamptz);
      CREATE TABLE admins(admin_id text PRIMARY KEY,user_id text);
      CREATE TABLE admin_activity_logs(admin_id text,action_type text,target_id text,target_type text,remarks text);
      CREATE TABLE notifications(user_id text,title text,body text,type text);
      CREATE TABLE customers(customer_id text,user_id text);
      CREATE TABLE stall_holders(stall_holder_id text,user_id text);
      CREATE TABLE orders(customer_id text,stall_holder_id text);
      INSERT INTO users(user_id,role) VALUES ('admin','admin'),('customer','customer'),('vendor','vendor');
      INSERT INTO admins VALUES ('a','admin');
      INSERT INTO customers VALUES ('c','customer'); INSERT INTO stall_holders VALUES ('s','vendor');
    `)
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261026010000_account_moderation.sql',import.meta.url)))
    const query = (sql: string) => db.query(sql)
    await assert.rejects(query(`SELECT moderate_account('customer','vendor','block')`), /denied/)
    await assert.rejects(query(`SELECT moderate_account('admin','admin','block')`), /denied/)
    await query(`SELECT moderate_account('admin','customer','notes','Private review note')`)
    assert.equal((await query(`SELECT * FROM notifications`)).rows.length,0)
    await query(`SELECT moderate_account('admin','customer','suspend','Private suspension note','Policy breach',now()-interval '1 minute',now()+interval '1 hour',true)`)
    assert.equal((await query(`SELECT * FROM users WHERE suspended_from<=now() AND suspended_until>now()`)).rows.length,1)
    const notices = (await query(`SELECT body FROM notifications`)).rows as {body:string}[]
    assert.match(notices[0].body,/Policy breach/)
    assert.doesNotMatch(notices[0].body,/Private/)
    await assert.rejects(query(`INSERT INTO orders VALUES ('c','s')`),/restricted/)
    assert.equal(((await query(`SELECT notes FROM account_admin_notes`)).rows[0] as {notes:string}).notes,'Private review note')
    await assert.rejects(query(`SELECT moderate_account('admin','customer','suspend','','Duplicate',now(),now()+interval '2 hours')`),/already has/)
    await query(`SELECT moderate_account('admin','customer','lift',p_suspension=>(SELECT id FROM account_suspensions LIMIT 1))`)
    assert.equal((await query(`SELECT * FROM users WHERE suspended_until>now()`)).rows.length,0)
    await query(`SELECT moderate_account('admin','vendor','suspend','','Scheduled',now()+interval '1 day',now()+interval '2 days',false)`)
    assert.equal((await query(`SELECT * FROM users WHERE suspended_from<=now() AND suspended_until>now()`)).rows.length,0)
    await query(`SELECT moderate_account('admin','vendor','block')`)
    await assert.rejects(query(`INSERT INTO orders VALUES ('c','s')`),/restricted/)
    assert.equal((await query(`SELECT * FROM users WHERE is_blocked`)).rows.length,1)
    await query(`SELECT moderate_account('admin','vendor','unblock')`)
    assert.equal((await query(`SELECT * FROM users WHERE is_blocked`)).rows.length,0)
    await query(`INSERT INTO orders VALUES ('c','s')`)
    // A notification failure must roll back the block, notes, and audit record.
    await db.exec(`ALTER TABLE notifications ADD CONSTRAINT reject_notice CHECK (title <> 'Account blocked') NOT VALID`)
    await assert.rejects(query(`SELECT moderate_account('admin','customer','block','should roll back')`))
    assert.equal((await query(`SELECT * FROM users WHERE is_blocked`)).rows.length,0)
    assert.equal(((await query(`SELECT notes FROM account_admin_notes WHERE user_id='customer'`)).rows[0] as {notes:string}).notes,'Private review note')
    await db.exec(`GRANT SELECT,UPDATE ON users TO authenticated; SET ROLE authenticated`)
    await assert.rejects(query(`SELECT * FROM account_admin_notes`),/permission denied/)
    await assert.rejects(query(`SELECT moderate_account('admin','customer','block')`),/permission denied/)
    await assert.rejects(query(`UPDATE users SET suspended_until=now()+interval '1 day' WHERE user_id='customer'`),/Only administrators/)
  } finally { await db.close() }
})
