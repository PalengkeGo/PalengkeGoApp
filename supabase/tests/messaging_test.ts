// Run: npx --yes --package=deno deno test --allow-read --allow-env supabase/tests/messaging_test.ts
// Isolated PostgreSQL; never connects to the live project.
import { PGlite } from 'npm:@electric-sql/pglite@0.3.14'
import { strict as assert } from 'node:assert'

Deno.test('chat authorization, atomic counters, read receipts and rollback', async () => {
  const db = new PGlite()
  try {
    await db.exec(`
      CREATE ROLE anon; CREATE ROLE authenticated;
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon;
      CREATE SCHEMA auth; CREATE SCHEMA realtime; CREATE SCHEMA storage;
      CREATE TABLE storage.buckets(id text PRIMARY KEY, name text, public boolean,
        file_size_limit bigint, allowed_mime_types text[]);
      CREATE TABLE storage.objects(bucket_id text, name text);
      ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
      GRANT USAGE ON SCHEMA storage TO anon, authenticated;
      GRANT SELECT,INSERT ON storage.objects TO anon, authenticated;
      CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS
        $$ SELECT coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
      CREATE FUNCTION realtime.topic() RETURNS text LANGUAGE sql STABLE AS
        $$ SELECT current_setting('realtime.topic', true) $$;
      CREATE TABLE realtime.messages (extension text);
      ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;
      GRANT USAGE ON SCHEMA public, auth, realtime TO anon, authenticated;
      GRANT SELECT,INSERT ON realtime.messages TO anon, authenticated;
      CREATE TABLE public.users(user_id text PRIMARY KEY, full_name text, role text,
        is_blocked boolean, profile_photo text);
      CREATE TABLE public.stall_holders(stall_holder_id text PRIMARY KEY, user_id text,
        stall_name text, is_blocked boolean, thumbnail_url text, banner_image_url text);
      CREATE TABLE public.customers(customer_id text, user_id text);
      CREATE TABLE public.orders(order_id text, stall_holder_id text, customer_id text);
      INSERT INTO users(user_id,full_name,role,is_blocked) VALUES ('customer','Customer','customer',false),
        ('vendor','Vendor','stallholder',false),('stranger','Stranger','customer',false);
      INSERT INTO stall_holders(stall_holder_id,user_id,stall_name,is_blocked)
        VALUES ('stall','vendor','Market Stall',false);
      CREATE PUBLICATION supabase_realtime;
    `)
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261021010000_in_app_messaging.sql', import.meta.url)))
    // Simulate existing chat data deployed outside migration history.
    await db.exec(`INSERT INTO conversations(id,stall_id,stall_name,customer_uid,customer_name,
      vendor_unread_count) VALUES ('existing','stall','Market Stall','customer','Customer',99);
      INSERT INTO messages(id,conversation_id,sender_id,sender_name,sender_role,text)
      VALUES ('old-message','existing','customer','Customer','customer','Existing message');`)
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261021020000_secure_messaging.sql', import.meta.url)))
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261021040000_revoke_anonymous_chat_rpc.sql', import.meta.url)))
    const scalar = async (sql: string) => (await db.query(sql)).rows[0] as Record<string, unknown>
    const login = async (uid?: string, issuer = 'palengkegodb', role = 'authenticated') => {
      await db.exec('RESET ROLE')
      await db.query("SELECT set_config('request.jwt.claims', $1, false)", [JSON.stringify(uid ? {
        sub: uid, iss: `https://securetoken.google.com/${issuer}`, aud: issuer,
      } : {})])
      await db.exec(`SET ROLE ${role}`)
    }
    assert.equal((await scalar('SELECT vendor_unread_count FROM conversations')).vendor_unread_count, 1)
    await login(undefined, 'palengkegodb', 'anon')
    await assert.rejects(db.query('SELECT * FROM messages'), /permission denied/)
    await assert.rejects(db.query("SELECT chat_send_message('existing','anonymous')"), /permission denied/)
    for (const uid of [undefined, 'stranger']) {
      await login(uid)
      assert.equal((await scalar('SELECT count(*)::int AS n FROM conversations')).n, 0)
      assert.equal((await scalar('SELECT count(*)::int AS n FROM messages')).n, 0)
      await assert.rejects(db.query("SELECT chat_send_message('existing','intrusion')"), /Chat access denied/)
      await assert.rejects(db.query("SELECT chat_mark_read('existing')"), /Chat access denied/)
      await assert.rejects(db.query("SELECT chat_get_or_create('stall','customer')"), /Chat access denied/)
    }
    await login('customer', 'untrusted-project')
    assert.equal((await scalar('SELECT count(*)::int AS n FROM conversations')).n, 0)
    await login('customer')
    assert.equal((await scalar("SELECT (chat_get_or_create('stall','customer')).id")).id, 'existing')
    await assert.rejects(db.query("UPDATE conversations SET vendor_unread_count=0"), /permission denied/)
    await assert.rejects(db.query("INSERT INTO messages(id) VALUES ('forged')"), /permission denied/)
    await assert.rejects(db.query("UPDATE messages SET text='edited'"), /permission denied/)
    await assert.rejects(db.query("DELETE FROM messages"), /permission denied/)
    await assert.rejects(db.query("SELECT chat_send_message('existing','')"), /Invalid message/)
    await assert.rejects(db.query("SELECT chat_send_message('existing','photo','file:///secret')"), /Invalid message/)
    await db.query("INSERT INTO storage.objects VALUES ('chat-attachments','existing/customer/photo.jpg')")
    await assert.rejects(db.query("INSERT INTO storage.objects VALUES ('chat-attachments','existing/vendor/forged.jpg')"), /row-level security/)
    await login('stranger')
    assert.equal((await scalar('SELECT count(*)::int AS n FROM storage.objects')).n, 0)
    await assert.rejects(db.query("INSERT INTO storage.objects VALUES ('chat-attachments','existing/stranger/photo.jpg')"), /row-level security/)
    await login('customer')
    // Queued sends must increment, never overwrite, the unread total.
    await Promise.all(Array.from({length: 20}, (_, i) =>
      db.query("SELECT chat_send_message('existing', $1)", [`message ${i}`])))
    assert.equal((await scalar('SELECT vendor_unread_count FROM conversations')).vendor_unread_count, 21)
    await db.query("SELECT chat_mark_read('existing')") // Customer cannot clear vendor's count.
    assert.equal((await scalar('SELECT vendor_unread_count FROM conversations')).vendor_unread_count, 21)
    await login('vendor', 'palengkegodb', 'authenticated')
    await db.query("SELECT chat_mark_read('existing')")
    assert.equal((await scalar('SELECT vendor_unread_count FROM conversations')).vendor_unread_count, 0)
    assert.equal((await scalar('SELECT count(*)::int AS n FROM messages WHERE NOT is_read')).n, 0)
    const sent = await scalar("SELECT * FROM chat_send_message('existing','Vendor reply')")
    assert.equal(sent.sender_id, 'stall')
    assert.equal(sent.sender_role, 'vendor')
    assert.equal(sent.sender_name, 'Market Stall')
    assert.equal((await scalar('SELECT customer_unread_count FROM conversations')).customer_unread_count, 1)
    await login('customer')
    await db.query("SELECT chat_send_message('existing','after read')")
    assert.equal((await scalar('SELECT vendor_unread_count FROM conversations')).vendor_unread_count, 1)
    // If the summary write fails, the message insert must roll back too.
    await db.exec(`RESET ROLE;
      CREATE FUNCTION reject_summary() RETURNS trigger LANGUAGE plpgsql AS
        $$ BEGIN RAISE EXCEPTION 'test failure'; END $$;
      CREATE TRIGGER reject_summary BEFORE UPDATE ON conversations FOR EACH ROW EXECUTE FUNCTION reject_summary();`)
    await login('customer')
    const before = (await scalar('SELECT count(*)::int AS n FROM messages')).n
    await assert.rejects(db.query("SELECT chat_send_message('existing','must roll back')"), /test failure/)
    assert.equal((await scalar('SELECT count(*)::int AS n FROM messages')).n, before)
    await db.exec('RESET ROLE; DROP TRIGGER reject_summary ON conversations;')
    // Typing rooms enforce membership even for valid identities from this app.
    await login('customer')
    await db.query("SELECT set_config('realtime.topic','chat-room-existing',false)")
    await db.query("INSERT INTO realtime.messages VALUES ('broadcast')")
    await login('stranger')
    await assert.rejects(db.query("INSERT INTO realtime.messages VALUES ('broadcast')"), /row-level security/)
    assert.equal((await scalar('SELECT count(*)::int AS n FROM realtime.messages')).n, 0)
    await db.exec("RESET ROLE; UPDATE users SET is_blocked=true WHERE user_id='customer';")
    await login('customer')
    assert.equal((await scalar('SELECT count(*)::int AS n FROM conversations')).n, 0)
    await assert.rejects(db.query("SELECT chat_mark_read('existing')"), /Chat access denied/)
  } finally {
    await db.close()
  }
})
