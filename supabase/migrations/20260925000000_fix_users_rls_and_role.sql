-- Fix users role check to allow 'vendor' alongside 'stallholder'
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check CHECK (role IN ('customer', 'stallholder', 'vendor', 'admin'));

-- Fix RLS policies on public.users so the app can register and read profiles
DROP POLICY IF EXISTS "Allow anon insert users" ON public.users;
CREATE POLICY "Allow anon insert users" ON public.users FOR INSERT WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Allow anon select users" ON public.users;
CREATE POLICY "Allow anon select users" ON public.users FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Allow anon update users" ON public.users;
CREATE POLICY "Allow anon update users" ON public.users FOR UPDATE USING (TRUE);

-- Also allow stall_holders and kyc_submissions to be inserted / read
DROP POLICY IF EXISTS "Allow anon insert stall_holders" ON public.stall_holders;
CREATE POLICY "Allow anon insert stall_holders" ON public.stall_holders FOR INSERT WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Allow anon select stall_holders" ON public.stall_holders;
CREATE POLICY "Allow anon select stall_holders" ON public.stall_holders FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Allow anon update stall_holders" ON public.stall_holders;
CREATE POLICY "Allow anon update stall_holders" ON public.stall_holders FOR UPDATE USING (TRUE);

DROP POLICY IF EXISTS "Allow anon insert kyc_submissions" ON public.kyc_submissions;
CREATE POLICY "Allow anon insert kyc_submissions" ON public.kyc_submissions FOR INSERT WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Allow anon select kyc_submissions" ON public.kyc_submissions;
CREATE POLICY "Allow anon select kyc_submissions" ON public.kyc_submissions FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Allow anon update kyc_submissions" ON public.kyc_submissions;
CREATE POLICY "Allow anon update kyc_submissions" ON public.kyc_submissions FOR UPDATE USING (TRUE);
