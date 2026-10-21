ALTER TABLE public.vendor_complaints
  ADD COLUMN IF NOT EXISTS evidence_paths text[] NOT NULL DEFAULT '{}';

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (
    type IN ('order_update', 'flash_sale', 'kyc_update', 'new_order', 'system_announcement', 'complaint', 'account_action')
  );

ALTER TABLE public.admin_activity_logs
  DROP CONSTRAINT IF EXISTS admin_activity_logs_action_type_check;
ALTER TABLE public.admin_activity_logs
  ADD CONSTRAINT admin_activity_logs_action_type_check CHECK (
    action_type IN (
      'approved_kyc', 'rejected_kyc', 'blocked_user', 'unblocked_user',
      'exported_report', 'reviewed_complaint', 'warned_user', 'suspended_vendor'
    )
  );

INSERT INTO storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
VALUES ('report-evidence', 'report-evidence', false, 5242880,
        ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];
