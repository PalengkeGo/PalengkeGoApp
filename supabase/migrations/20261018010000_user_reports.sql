-- User and Stallholder Reports and Complaints table for PalengkeGoAPP and Palengke Admin.
CREATE TABLE IF NOT EXISTS public.reports (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  type TEXT NOT NULL DEFAULT 'Customer',
  account_issue TEXT NOT NULL DEFAULT '',
  category TEXT DEFAULT 'General',
  submitted_by TEXT NOT NULL DEFAULT 'Customer',
  reason TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  reporter_email TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  vendor_name TEXT DEFAULT '',
  owner TEXT DEFAULT '',
  stall_number TEXT DEFAULT '',
  previous_violations INTEGER DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  priority TEXT NOT NULL DEFAULT 'medium',
  notes TEXT DEFAULT '',
  decision TEXT,
  action_taken TEXT,
  resolution_note TEXT,
  resolved_at TIMESTAMPTZ,
  resolved_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reports_user_id ON public.reports (user_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports (status);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON public.reports (created_at DESC);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anon select reports" ON public.reports;
CREATE POLICY "Allow anon select reports" ON public.reports FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Allow anon insert reports" ON public.reports;
CREATE POLICY "Allow anon insert reports" ON public.reports FOR INSERT WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Allow anon update reports" ON public.reports;
CREATE POLICY "Allow anon update reports" ON public.reports FOR UPDATE USING (TRUE);

GRANT ALL ON public.reports TO anon, authenticated, service_role;

-- Policies for in-app resolution notifications between Admin and App
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anon select notifications" ON public.notifications;
CREATE POLICY "Allow anon select notifications" ON public.notifications FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Allow anon insert notifications" ON public.notifications;
CREATE POLICY "Allow anon insert notifications" ON public.notifications FOR INSERT WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Allow anon update notifications" ON public.notifications;
CREATE POLICY "Allow anon update notifications" ON public.notifications FOR UPDATE USING (TRUE);

GRANT ALL ON public.notifications TO anon, authenticated, service_role;

-- Enable Realtime CDC publication for reports
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'reports'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.reports;
  END IF;
END $$;
