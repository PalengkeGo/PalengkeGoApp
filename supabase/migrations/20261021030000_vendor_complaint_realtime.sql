-- Notify the admin portal over Supabase Realtime without exposing report data.
-- The portal fetches complaint details through the authenticated admin function.
CREATE OR REPLACE FUNCTION public.broadcast_vendor_complaint_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, realtime
AS $$
BEGIN
  PERFORM realtime.send(
    jsonb_build_object('table', 'vendor_complaints'),
    'complaint_changed',
    'admin-complaints',
    false
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS vendor_complaint_broadcast_change ON public.vendor_complaints;
CREATE TRIGGER vendor_complaint_broadcast_change
AFTER INSERT OR UPDATE ON public.vendor_complaints
FOR EACH ROW EXECUTE FUNCTION public.broadcast_vendor_complaint_change();
