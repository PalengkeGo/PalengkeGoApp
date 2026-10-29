BEGIN;

ALTER TABLE public.admin_activity_logs
  DROP CONSTRAINT IF EXISTS admin_activity_logs_action_type_check;
ALTER TABLE public.admin_activity_logs
  ADD CONSTRAINT admin_activity_logs_action_type_check CHECK (
    action_type IN (
      'approved_kyc', 'rejected_kyc', 'blocked_user', 'unblocked_user',
      'exported_report', 'reviewed_complaint', 'warned_user',
      'suspended_vendor', 'suspended_user', 'lifted_suspension',
      'updated_account_notes', 'resolved_report', 'admin_logged_in',
      'admin_logged_out', 'updated_admin_profile', 'published_announcement',
      'updated_announcement', 'deleted_announcement'
    )
  );

ALTER TABLE public.admin_activity_logs
  DROP CONSTRAINT IF EXISTS admin_activity_logs_target_type_check;
ALTER TABLE public.admin_activity_logs
  ADD CONSTRAINT admin_activity_logs_target_type_check CHECK (
    target_type IS NULL OR target_type IN (
      'user', 'stallholder', 'kyc', 'report', 'authentication',
      'announcement', 'product', 'system'
    )
  );

COMMIT;
