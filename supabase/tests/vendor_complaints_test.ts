// Run: npx --yes --package=deno deno test --allow-read supabase/tests/vendor_complaints_test.ts
// Runs in isolated PGlite; it never connects to the linked Supabase project.
import { PGlite } from 'npm:@electric-sql/pglite@0.3.14'
import { strict as assert } from 'node:assert'
import { validateEvidencePaths } from '../functions/_shared/complaints.ts'

Deno.test('report evidence paths are scoped to the reporter and capped at five', () => {
  assert.deepEqual(
    validateEvidencePaths(['customer-1/reports/photo.jpg'], 'customer-1'),
    ['customer-1/reports/photo.jpg'],
  )
  assert.throws(() => validateEvidencePaths(['someone-else/reports/photo.jpg'], 'customer-1'))
  assert.throws(() => validateEvidencePaths(
    Array.from({ length: 6 }, (_, i) => `customer-1/reports/${i}.jpg`),
    'customer-1',
  ))
})

Deno.test('vendor reports create admin notifications and realtime events', async () => {
  const db = new PGlite()
  try {
    await db.exec(`
      CREATE SCHEMA storage;
      CREATE TABLE storage.buckets (
        id text PRIMARY KEY, name text NOT NULL, public boolean NOT NULL,
        file_size_limit integer, allowed_mime_types text[]
      );
      CREATE ROLE service_role;
      CREATE TABLE public.users (user_id text PRIMARY KEY, role text NOT NULL);
      CREATE TABLE public.stall_holders (
        stall_holder_id text PRIMARY KEY, user_id text NOT NULL, stall_name text NOT NULL
      );
      CREATE TABLE public.admins (admin_id text PRIMARY KEY);
      CREATE TABLE public.notifications (
        user_id text NOT NULL, title text NOT NULL, body text NOT NULL,
        type text NOT NULL CHECK (type IN ('order_update','flash_sale','kyc_update','new_order','system_announcement')),
        reference_id text, is_read boolean NOT NULL DEFAULT false,
        created_at timestamptz NOT NULL DEFAULT now()
      );
      CREATE TABLE public.admin_activity_logs (
        action_type text NOT NULL CHECK (action_type IN ('approved_kyc','rejected_kyc','blocked_user','unblocked_user','exported_report'))
      );
      CREATE SCHEMA realtime;
      CREATE TABLE realtime.events (payload jsonb, event_name text, topic text, is_private boolean);
      CREATE FUNCTION realtime.send(p_payload jsonb, p_event text, p_topic text, p_private boolean)
      RETURNS void LANGUAGE sql AS $$
        INSERT INTO realtime.events VALUES (p_payload, p_event, p_topic, p_private)
      $$;
    `)
    await db.exec(await Deno.readTextFile(
      new URL('../manual_sql/vendor_complaints_admin_realtime.sql', import.meta.url),
    ))
    await db.exec(`
      INSERT INTO public.users(user_id, role) VALUES ('admin-1','admin'), ('customer-1','customer');
      INSERT INTO public.admins(admin_id) VALUES ('admin-record-1');
      INSERT INTO public.stall_holders(stall_holder_id,user_id,stall_name)
        VALUES ('stall-1','vendor-1','Fruit Stand');
      INSERT INTO public.vendor_complaints(complaint_id,reporter_user_id,stall_holder_id,reason)
        VALUES ('complaint-1','customer-1','stall-1','Unsafe products');
      INSERT INTO public.vendor_complaints(
        complaint_id,reporter_user_id,stall_holder_id,report_type,reason,details
      ) VALUES ('complaint-2','customer-1',NULL,'support','App Issue','Checkout gets stuck');
      UPDATE public.vendor_complaints SET status='reviewing' WHERE complaint_id='complaint-1';
    `)

    const complaints = await db.query<{
      complaint_id: string
      status: string
      report_type: string
      stall_holder_id: string | null
      evidence_paths: string[]
    }>(
      'SELECT complaint_id,status,report_type,stall_holder_id,evidence_paths FROM public.vendor_complaints ORDER BY complaint_id',
    )
    assert.deepEqual(complaints.rows, [
      { complaint_id: 'complaint-1', status: 'reviewing', report_type: 'vendor', stall_holder_id: 'stall-1', evidence_paths: [] },
      { complaint_id: 'complaint-2', status: 'open', report_type: 'support', stall_holder_id: null, evidence_paths: [] },
    ])
    const notifications = await db.query<{ user_id: string; type: string; reference_id: string }>(
      'SELECT user_id,type,reference_id FROM public.notifications ORDER BY reference_id',
    )
    assert.deepEqual(notifications.rows, [
      { user_id: 'admin-1', type: 'complaint', reference_id: 'complaint-1' },
      { user_id: 'admin-1', type: 'complaint', reference_id: 'complaint-2' },
    ])
    const events = await db.query<{ event_name: string; topic: string }>(
      'SELECT event_name,topic FROM realtime.events ORDER BY event_name',
    )
    assert.equal(events.rows.length, 3)
    assert.ok(events.rows.every((event) =>
      event.event_name === 'complaint_changed' && event.topic === 'admin-complaints'
    ))
  } finally {
    await db.close()
  }
})
