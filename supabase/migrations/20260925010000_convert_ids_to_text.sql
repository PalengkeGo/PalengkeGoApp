-- Convert user_id, stall_holder_id, customer_id, and kyc_id from UUID to TEXT
-- to natively support Firebase Auth UIDs and flexible string IDs.

-- 1. Drop all RLS policies that reference user_id, stall_holder_id, or customer_id
DROP POLICY IF EXISTS "Users can read own record" ON users;
DROP POLICY IF EXISTS "Admins can read all users" ON users;
DROP POLICY IF EXISTS "Users can update own record" ON users;
DROP POLICY IF EXISTS "Allow anon insert users" ON users;
DROP POLICY IF EXISTS "Allow anon select users" ON users;
DROP POLICY IF EXISTS "Allow anon update users" ON users;

DROP POLICY IF EXISTS "Customers can read own record" ON customers;
DROP POLICY IF EXISTS "Admins can read all customers" ON customers;

DROP POLICY IF EXISTS "Anyone can read approved stall holders" ON stall_holders;
DROP POLICY IF EXISTS "Stall holders can read own record" ON stall_holders;
DROP POLICY IF EXISTS "Admins can read all stall holders" ON stall_holders;
DROP POLICY IF EXISTS "Stall holders can update own record" ON stall_holders;
DROP POLICY IF EXISTS "Allow anon insert stall_holders" ON stall_holders;
DROP POLICY IF EXISTS "Allow anon select stall_holders" ON stall_holders;
DROP POLICY IF EXISTS "Allow anon update stall_holders" ON stall_holders;

DROP POLICY IF EXISTS "Anyone can read visible in-stock products" ON products;
DROP POLICY IF EXISTS "Stall holders can manage own products" ON products;

DROP POLICY IF EXISTS "Customers can manage own cart" ON cart;

DROP POLICY IF EXISTS "Customers can read own orders" ON orders;
DROP POLICY IF EXISTS "Stall holders can read own orders" ON orders;
DROP POLICY IF EXISTS "Admins can read all orders" ON orders;

DROP POLICY IF EXISTS "Stall holders can read own KYC" ON kyc_submissions;
DROP POLICY IF EXISTS "Admins can read all KYC submissions" ON kyc_submissions;
DROP POLICY IF EXISTS "Admins can update KYC submissions" ON kyc_submissions;
DROP POLICY IF EXISTS "Allow anon insert kyc_submissions" ON kyc_submissions;
DROP POLICY IF EXISTS "Allow anon select kyc_submissions" ON kyc_submissions;
DROP POLICY IF EXISTS "Allow anon update kyc_submissions" ON kyc_submissions;

DROP POLICY IF EXISTS "Users can read own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;

DROP POLICY IF EXISTS "Customers can insert own ratings" ON ratings;
DROP POLICY IF EXISTS "Anyone can read ratings" ON ratings;

DROP POLICY IF EXISTS "Anyone can read active promos" ON promos;
DROP POLICY IF EXISTS "Stall holders can manage own promos" ON promos;

DROP POLICY IF EXISTS "Stall holders can read own sales" ON sales_summary;
DROP POLICY IF EXISTS "Admins can read all sales" ON sales_summary;

-- 2. Drop referencing foreign key constraints
ALTER TABLE customers DROP CONSTRAINT IF EXISTS customers_user_id_fkey;
ALTER TABLE customer_addresses DROP CONSTRAINT IF EXISTS customer_addresses_customer_id_fkey;
ALTER TABLE search_logs DROP CONSTRAINT IF EXISTS search_logs_customer_id_fkey;
ALTER TABLE stall_holders DROP CONSTRAINT IF EXISTS stall_holders_user_id_fkey;
ALTER TABLE stall_holder_delivery_settings DROP CONSTRAINT IF EXISTS stall_holder_delivery_settings_stall_holder_id_fkey;
ALTER TABLE stall_holder_schedule DROP CONSTRAINT IF EXISTS stall_holder_schedule_stall_holder_id_fkey;
ALTER TABLE stall_holder_ratings_summary DROP CONSTRAINT IF EXISTS stall_holder_ratings_summary_stall_holder_id_fkey;
ALTER TABLE admins DROP CONSTRAINT IF EXISTS admins_user_id_fkey;
ALTER TABLE admin_activity_logs DROP CONSTRAINT IF EXISTS admin_activity_logs_admin_id_fkey;
ALTER TABLE system_announcements DROP CONSTRAINT IF EXISTS system_announcements_admin_id_fkey;
ALTER TABLE delivery_rate_config DROP CONSTRAINT IF EXISTS delivery_rate_config_set_by_fkey;
ALTER TABLE app_settings DROP CONSTRAINT IF EXISTS app_settings_updated_by_fkey;
ALTER TABLE kyc_submissions DROP CONSTRAINT IF EXISTS kyc_submissions_stall_holder_id_fkey;
ALTER TABLE kyc_submissions DROP CONSTRAINT IF EXISTS kyc_submissions_reviewed_by_fkey;
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_stall_holder_id_fkey;
ALTER TABLE product_category_cross_tag DROP CONSTRAINT IF EXISTS product_category_cross_tag_stall_holder_id_fkey;
ALTER TABLE cart DROP CONSTRAINT IF EXISTS cart_stall_holder_id_fkey;
ALTER TABLE cart DROP CONSTRAINT IF EXISTS cart_customer_id_fkey;
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_stall_holder_id_fkey;
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_customer_id_fkey;
ALTER TABLE order_status_history DROP CONSTRAINT IF EXISTS order_status_history_changed_by_fkey;
ALTER TABLE ratings DROP CONSTRAINT IF EXISTS ratings_stall_holder_id_fkey;
ALTER TABLE ratings DROP CONSTRAINT IF EXISTS ratings_customer_id_fkey;
ALTER TABLE promos DROP CONSTRAINT IF EXISTS promos_stall_holder_id_fkey;
ALTER TABLE sales_summary DROP CONSTRAINT IF EXISTS sales_summary_stall_holder_id_fkey;
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_user_id_fkey;
ALTER TABLE report_exports DROP CONSTRAINT IF EXISTS report_exports_exported_by_fkey;

-- 3. Alter column types on users table
ALTER TABLE users ALTER COLUMN user_id DROP DEFAULT;
ALTER TABLE users ALTER COLUMN user_id TYPE TEXT;
ALTER TABLE users ALTER COLUMN user_id SET DEFAULT gen_random_uuid()::text;

-- 4. Alter column types on customers & addresses & search_logs
ALTER TABLE customers ALTER COLUMN customer_id DROP DEFAULT;
ALTER TABLE customers ALTER COLUMN customer_id TYPE TEXT;
ALTER TABLE customers ALTER COLUMN customer_id SET DEFAULT gen_random_uuid()::text;
ALTER TABLE customers ALTER COLUMN user_id TYPE TEXT;
ALTER TABLE customer_addresses ALTER COLUMN customer_id TYPE TEXT;
ALTER TABLE search_logs ALTER COLUMN customer_id TYPE TEXT;

-- 5. Alter column types on stall_holders & related tables
ALTER TABLE stall_holders ALTER COLUMN stall_holder_id DROP DEFAULT;
ALTER TABLE stall_holders ALTER COLUMN stall_holder_id TYPE TEXT;
ALTER TABLE stall_holders ALTER COLUMN stall_holder_id SET DEFAULT gen_random_uuid()::text;
ALTER TABLE stall_holders ALTER COLUMN user_id TYPE TEXT;

ALTER TABLE stall_holder_delivery_settings ALTER COLUMN stall_holder_id TYPE TEXT;
ALTER TABLE stall_holder_schedule ALTER COLUMN stall_holder_id TYPE TEXT;
ALTER TABLE stall_holder_ratings_summary ALTER COLUMN stall_holder_id TYPE TEXT;

-- 6. Alter column types on admins & activity logs & configs
ALTER TABLE admins ALTER COLUMN admin_id DROP DEFAULT;
ALTER TABLE admins ALTER COLUMN admin_id TYPE TEXT;
ALTER TABLE admins ALTER COLUMN admin_id SET DEFAULT gen_random_uuid()::text;
ALTER TABLE admins ALTER COLUMN user_id TYPE TEXT;
ALTER TABLE admin_activity_logs ALTER COLUMN admin_id TYPE TEXT;
ALTER TABLE system_announcements ALTER COLUMN admin_id TYPE TEXT;
ALTER TABLE delivery_rate_config ALTER COLUMN set_by TYPE TEXT;
ALTER TABLE app_settings ALTER COLUMN updated_by TYPE TEXT;

-- 7. Alter column types on kyc_submissions
ALTER TABLE kyc_submissions ALTER COLUMN kyc_id DROP DEFAULT;
ALTER TABLE kyc_submissions ALTER COLUMN kyc_id TYPE TEXT;
ALTER TABLE kyc_submissions ALTER COLUMN kyc_id SET DEFAULT gen_random_uuid()::text;
ALTER TABLE kyc_submissions ALTER COLUMN stall_holder_id TYPE TEXT;
ALTER TABLE kyc_submissions ALTER COLUMN reviewed_by TYPE TEXT;
ALTER TABLE kyc_submissions ALTER COLUMN selfie_url DROP NOT NULL;
ALTER TABLE kyc_submissions ALTER COLUMN selfie_url SET DEFAULT '';

-- 8. Alter column types on other dependent tables
ALTER TABLE products ALTER COLUMN stall_holder_id TYPE TEXT;
ALTER TABLE product_category_cross_tag ALTER COLUMN stall_holder_id TYPE TEXT;
ALTER TABLE cart ALTER COLUMN stall_holder_id TYPE TEXT;
ALTER TABLE cart ALTER COLUMN customer_id TYPE TEXT;
ALTER TABLE orders ALTER COLUMN stall_holder_id TYPE TEXT;
ALTER TABLE orders ALTER COLUMN customer_id TYPE TEXT;
ALTER TABLE order_status_history ALTER COLUMN changed_by TYPE TEXT;
ALTER TABLE ratings ALTER COLUMN stall_holder_id TYPE TEXT;
ALTER TABLE ratings ALTER COLUMN customer_id TYPE TEXT;
ALTER TABLE promos ALTER COLUMN stall_holder_id TYPE TEXT;
ALTER TABLE sales_summary ALTER COLUMN stall_holder_id TYPE TEXT;
ALTER TABLE notifications ALTER COLUMN user_id TYPE TEXT;
ALTER TABLE report_exports ALTER COLUMN exported_by TYPE TEXT;

-- 9. Re-add foreign key constraints
ALTER TABLE customers ADD CONSTRAINT customers_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;
ALTER TABLE customer_addresses ADD CONSTRAINT customer_addresses_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE;
ALTER TABLE search_logs ADD CONSTRAINT search_logs_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE;
ALTER TABLE stall_holders ADD CONSTRAINT stall_holders_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;
ALTER TABLE stall_holder_delivery_settings ADD CONSTRAINT stall_holder_delivery_settings_stall_holder_id_fkey FOREIGN KEY (stall_holder_id) REFERENCES stall_holders(stall_holder_id) ON DELETE CASCADE;
ALTER TABLE stall_holder_schedule ADD CONSTRAINT stall_holder_schedule_stall_holder_id_fkey FOREIGN KEY (stall_holder_id) REFERENCES stall_holders(stall_holder_id) ON DELETE CASCADE;
ALTER TABLE stall_holder_ratings_summary ADD CONSTRAINT stall_holder_ratings_summary_stall_holder_id_fkey FOREIGN KEY (stall_holder_id) REFERENCES stall_holders(stall_holder_id) ON DELETE CASCADE;
ALTER TABLE admins ADD CONSTRAINT admins_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;
ALTER TABLE admin_activity_logs ADD CONSTRAINT admin_activity_logs_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES admins(admin_id);
ALTER TABLE system_announcements ADD CONSTRAINT system_announcements_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES admins(admin_id);
ALTER TABLE delivery_rate_config ADD CONSTRAINT delivery_rate_config_set_by_fkey FOREIGN KEY (set_by) REFERENCES admins(admin_id);
ALTER TABLE app_settings ADD CONSTRAINT app_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES admins(admin_id);
ALTER TABLE kyc_submissions ADD CONSTRAINT kyc_submissions_stall_holder_id_fkey FOREIGN KEY (stall_holder_id) REFERENCES stall_holders(stall_holder_id) ON DELETE CASCADE;
ALTER TABLE products ADD CONSTRAINT products_stall_holder_id_fkey FOREIGN KEY (stall_holder_id) REFERENCES stall_holders(stall_holder_id) ON DELETE CASCADE;
ALTER TABLE product_category_cross_tag ADD CONSTRAINT product_category_cross_tag_stall_holder_id_fkey FOREIGN KEY (stall_holder_id) REFERENCES stall_holders(stall_holder_id);
ALTER TABLE cart ADD CONSTRAINT cart_stall_holder_id_fkey FOREIGN KEY (stall_holder_id) REFERENCES stall_holders(stall_holder_id);
ALTER TABLE orders ADD CONSTRAINT orders_stall_holder_id_fkey FOREIGN KEY (stall_holder_id) REFERENCES stall_holders(stall_holder_id);
ALTER TABLE ratings ADD CONSTRAINT ratings_stall_holder_id_fkey FOREIGN KEY (stall_holder_id) REFERENCES stall_holders(stall_holder_id);
ALTER TABLE promos ADD CONSTRAINT promos_stall_holder_id_fkey FOREIGN KEY (stall_holder_id) REFERENCES stall_holders(stall_holder_id);
ALTER TABLE sales_summary ADD CONSTRAINT sales_summary_stall_holder_id_fkey FOREIGN KEY (stall_holder_id) REFERENCES stall_holders(stall_holder_id);
ALTER TABLE notifications ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;
ALTER TABLE report_exports ADD CONSTRAINT report_exports_exported_by_fkey FOREIGN KEY (exported_by) REFERENCES users(user_id);

-- 10. Re-create RLS policies for users, stall_holders, and kyc_submissions
CREATE POLICY "Allow anon insert users" ON public.users FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "Allow anon select users" ON public.users FOR SELECT USING (TRUE);
CREATE POLICY "Allow anon update users" ON public.users FOR UPDATE USING (TRUE);

CREATE POLICY "Allow anon insert stall_holders" ON public.stall_holders FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "Allow anon select stall_holders" ON public.stall_holders FOR SELECT USING (TRUE);
CREATE POLICY "Allow anon update stall_holders" ON public.stall_holders FOR UPDATE USING (TRUE);

CREATE POLICY "Allow anon insert kyc_submissions" ON public.kyc_submissions FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "Allow anon select kyc_submissions" ON public.kyc_submissions FOR SELECT USING (TRUE);
CREATE POLICY "Allow anon update kyc_submissions" ON public.kyc_submissions FOR UPDATE USING (TRUE);

-- Allow public read of products and stall holders
CREATE POLICY "Anyone can read stall holders" ON public.stall_holders FOR SELECT USING (TRUE);
CREATE POLICY "Anyone can read products" ON public.products FOR SELECT USING (TRUE);
CREATE OR REPLACE FUNCTION handle_kyc_approval()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'approved' AND (OLD.status IS DISTINCT FROM 'approved') THEN
    UPDATE public.stall_holders
    SET is_kyc_approved = TRUE, kyc_status = 'approved'
    WHERE stall_holder_id = NEW.stall_holder_id;

    UPDATE public.users
    SET role = 'vendor'
    WHERE user_id = (
      SELECT user_id FROM public.stall_holders WHERE stall_holder_id = NEW.stall_holder_id LIMIT 1
    );
  ELSIF NEW.status = 'rejected' AND (OLD.status IS DISTINCT FROM 'rejected') THEN
    UPDATE public.stall_holders
    SET is_kyc_approved = FALSE, kyc_status = 'rejected'
    WHERE stall_holder_id = NEW.stall_holder_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_kyc_approval ON public.kyc_submissions;
CREATE TRIGGER trg_kyc_approval
AFTER UPDATE OF status ON public.kyc_submissions
FOR EACH ROW
EXECUTE FUNCTION handle_kyc_approval();
