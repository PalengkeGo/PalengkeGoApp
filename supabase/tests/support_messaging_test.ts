// Run with: npx --yes --package=deno deno test supabase/tests/support_messaging_test.ts
// Uses an isolated PostgreSQL instance; it never connects to the linked project.
import { PGlite } from 'npm:@electric-sql/pglite@0.3.14'
import { strict as assert } from 'node:assert'

Deno.test('support chat keeps rows private and updates read counts atomically', async () => {
  const db = new PGlite()
  try {
    await db.exec(`
      CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
      CREATE TABLE public.users(user_id text PRIMARY KEY);
      CREATE TABLE public.admins(admin_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id text UNIQUE);
      CREATE TABLE public.admin_activity_logs(
        admin_id uuid, action_type text, target_id text, target_type text,
        remarks text, performed_at timestamptz DEFAULT now()
      );
      INSERT INTO public.users(user_id) VALUES ('customer-1'), ('vendor-1'), ('admin-1'), ('customer-2');
      INSERT INTO public.admins(user_id) VALUES ('admin-1');
    `)
    await db.exec(await Deno.readTextFile(
      new URL('../migrations/20261027020000_secure_admin_support_messaging.sql', import.meta.url),
    ))

    await db.exec('SET ROLE anon')
    await assert.rejects(db.query('SELECT * FROM public.support_conversations'), /permission denied/)
    await assert.rejects(db.query("SELECT public.support_start_conversation('customer-1','customer','Help','Hi')"), /permission denied/)
    await db.exec('RESET ROLE; SET ROLE service_role')

    const started = await db.query(
      "SELECT id::text AS id FROM public.support_start_conversation('customer-1','customer','Order help','Please help')",
    )
    const conversationId = String((started.rows[0] as { id: string }).id)
    const initial = await db.query(
      'SELECT admin_unread_count FROM public.support_conversations WHERE id = $1',
      [conversationId],
    )
    assert.equal((initial.rows[0] as { admin_unread_count: number }).admin_unread_count, 1)

    await db.query("SELECT public.support_mark_read($1, 'admin-1', 'admin')", [conversationId])
    await db.query(
      "SELECT public.support_send_message($1, 'admin-1', 'admin', 'We are checking this')",
      [conversationId],
    )
    const pendingUserRead = await db.query(
      'SELECT user_unread_count FROM public.support_conversations WHERE id = $1',
      [conversationId],
    )
    assert.equal((pendingUserRead.rows[0] as { user_unread_count: number }).user_unread_count, 1)

    await assert.rejects(
      db.query("SELECT public.support_send_message($1, 'customer-2', 'customer', 'Intrusion')", [conversationId]),
      /access denied/,
    )
    await db.query("SELECT public.support_mark_read($1, 'customer-1', 'customer')", [conversationId])
    const cleared = await db.query(
      'SELECT user_unread_count FROM public.support_conversations WHERE id = $1',
      [conversationId],
    )
    assert.equal((cleared.rows[0] as { user_unread_count: number }).user_unread_count, 0)
  } finally {
    await db.close()
  }
})
