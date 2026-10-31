import { PGlite } from 'npm:@electric-sql/pglite@0.3.14'
import { strict as assert } from 'node:assert'

Deno.test('stallholder/admin support enforces ownership, roles, private photos and read counts', async () => {
  const db = new PGlite()
  try {
    await db.exec(`
      CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
      CREATE SCHEMA storage;
      CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
      CREATE TABLE storage.objects(bucket_id text,name text);
      CREATE TABLE public.users(user_id text PRIMARY KEY,role text,is_blocked boolean DEFAULT false,suspended_from timestamptz,suspended_until timestamptz);
      CREATE TABLE public.stall_holders(stall_holder_id text PRIMARY KEY,user_id text,is_blocked boolean DEFAULT false,is_kyc_approved boolean,kyc_status text);
      CREATE TABLE public.admins(admin_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id text);
      CREATE TABLE public.admin_activity_logs(admin_id uuid,action_type text,target_id text,target_type text,remarks text);
      CREATE FUNCTION public.chat_uid() RETURNS text LANGUAGE sql STABLE AS $$ SELECT current_setting('request.jwt.claim.sub',true) $$;
      INSERT INTO public.users(user_id,role) VALUES ('vendor-1','vendor'),('vendor-2','vendor'),('pending','vendor'),('customer-1','customer'),('admin-1','admin');
      INSERT INTO public.stall_holders(stall_holder_id,user_id,is_kyc_approved,kyc_status) VALUES ('s1','vendor-1',true,'approved'),('s2','vendor-2',true,'approved'),('s3','pending',false,'pending');
      INSERT INTO public.admins(user_id) VALUES ('admin-1');
    `)
    for (const file of ['20261027020000_secure_admin_support_messaging.sql','20261029010000_stallholder_admin_chat.sql']) {
      await db.exec(await Deno.readTextFile(new URL(`../migrations/${file}`, import.meta.url)))
    }
    await db.exec('SET ROLE service_role')
    for (const [uid,role] of [['customer-1','customer'],['customer-1','vendor'],['pending','vendor']]) {
      await assert.rejects(db.query('SELECT public.support_start_conversation($1,$2,$3,$4)',[uid,role,'Help','Test']), /Invalid support conversation/)
    }
    const created = await db.query("SELECT id::text id FROM public.support_start_conversation('vendor-1','vendor','Permit','Please help')")
    const id = (created.rows[0] as {id:string}).id
    await assert.rejects(db.query("SELECT public.support_send_message($1,'vendor-2','vendor','Intrusion')",[id]), /access denied/)
    await assert.rejects(db.query("SELECT public.support_send_message($1,'customer-1','admin','Impersonation')",[id]), /Invalid support message/)
    await db.query("SELECT public.support_send_message($1,'admin-1','admin','We can help')",[id])
    await db.query("SELECT public.support_mark_read($1,'vendor-1','vendor')",[id])
    const counts = await db.query('SELECT user_unread_count,admin_unread_count FROM public.support_conversations WHERE id=$1',[id])
    assert.deepEqual(counts.rows[0], {user_unread_count:0,admin_unread_count:1})
    const photo = `${id}/vendor-1/photo.png`
    await assert.rejects(db.query("SELECT public.support_send_photo($1,'vendor-1','vendor','',$2)",[id,photo]), /Invalid support message/)
    await db.exec('RESET ROLE')
    await db.query("INSERT INTO storage.objects VALUES ('support-attachments',$1)",[photo])
    await db.exec('SET ROLE service_role')
    await db.query("SELECT public.support_send_photo($1,'vendor-1','vendor','',$2)",[id,photo])
    await db.exec('RESET ROLE; SET ROLE authenticated')
    for (const uid of ['vendor-2','customer-1','pending']) {
      await db.query("SELECT set_config('request.jwt.claim.sub',$1,false)",[uid])
      const hidden = await db.query('SELECT * FROM public.support_messages')
      assert.equal(hidden.rows.length,0)
    }
    await db.query("SELECT set_config('request.jwt.claim.sub','vendor-1',false)")
    assert.equal((await db.query('SELECT * FROM public.support_messages')).rows.length,3)
    await assert.rejects(db.query("UPDATE public.support_conversations SET user_unread_count=0"), /permission denied/)
    await assert.rejects(db.query("SELECT public.support_send_message($1,'vendor-1','vendor','Bypass')",[id]), /permission denied/)
    await db.query("SELECT set_config('request.jwt.claim.sub','admin-1',false)")
    assert.equal((await db.query('SELECT * FROM public.support_messages')).rows.length,3)
    await db.exec("RESET ROLE; UPDATE public.users SET is_blocked=true WHERE user_id='vendor-1'; SET ROLE authenticated")
    await db.query("SELECT set_config('request.jwt.claim.sub','vendor-1',false)")
    assert.equal((await db.query('SELECT * FROM public.support_messages')).rows.length,0)
    await db.exec('RESET ROLE; SET ROLE service_role')
    await assert.rejects(db.query("SELECT public.support_send_message($1,'vendor-1','vendor','Blocked')",[id]), /Invalid support message/)
    await db.exec('RESET ROLE')
    assert.equal((await db.query<{public:boolean}>("SELECT public FROM storage.buckets WHERE id='support-attachments'")).rows[0].public,false)
    // Identical timestamps must still paginate deterministically by UUID.
    await db.query(`INSERT INTO public.support_messages(conversation_id,sender_user_id,sender_role,body,created_at)
      SELECT $1,'admin-1','admin','Page test', '2026-10-30T00:00:00Z' FROM generate_series(1,75)`,[id])
    const first = await db.query('SELECT id,created_at FROM public.support_messages WHERE conversation_id=$1 ORDER BY created_at DESC,id DESC LIMIT 50',[id])
    const last = first.rows.at(-1) as {id:string;created_at:Date}
    const second = await db.query('SELECT id FROM public.support_messages WHERE conversation_id=$1 AND (created_at,id)<($2,$3::uuid) ORDER BY created_at DESC,id DESC LIMIT 50',[id,last.created_at,last.id])
    assert.equal(new Set([...first.rows,...second.rows].map((row:any)=>row.id)).size,78)
  } finally { await db.close() }
})
