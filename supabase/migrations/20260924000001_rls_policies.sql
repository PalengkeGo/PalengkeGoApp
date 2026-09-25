-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE stall_holders ENABLE ROW LEVEL SECURITY;
ALTER TABLE stall_holder_delivery_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE stall_holder_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE stall_holder_ratings_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE kyc_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_category_cross_tag ENABLE ROW LEVEL SECURITY;
ALTER TABLE cart ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE promos ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE flash_sale_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_exports ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_rate_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE search_logs ENABLE ROW LEVEL SECURITY;

-- Helper function to get user role from users table
CREATE OR REPLACE FUNCTION get_user_role(uid UUID)
RETURNS TEXT AS $$
  SELECT role FROM users WHERE user_id = uid;
$$ LANGUAGE SQL SECURITY DEFINER;

-- USERS table policies
CREATE POLICY "Users can read own record" ON users
  FOR SELECT USING (auth.uid()::uuid = user_id);
CREATE POLICY "Admins can read all users" ON users
  FOR SELECT USING (get_user_role(auth.uid()::uuid) = 'admin');
CREATE POLICY "Users can update own record" ON users
  FOR UPDATE USING (auth.uid()::uuid = user_id);

-- CUSTOMERS policies
CREATE POLICY "Customers can read own record" ON customers
  FOR SELECT USING (user_id = auth.uid()::uuid);
CREATE POLICY "Admins can read all customers" ON customers
  FOR SELECT USING (get_user_role(auth.uid()::uuid) = 'admin');

-- STALL_HOLDERS policies
ALTER TABLE stall_holders ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT FALSE;
CREATE POLICY "Anyone can read approved stall holders" ON stall_holders
  FOR SELECT USING (is_kyc_approved = TRUE AND is_blocked = FALSE);
CREATE POLICY "Stall holders can read own record" ON stall_holders
  FOR SELECT USING (user_id = auth.uid()::uuid);
CREATE POLICY "Admins can read all stall holders" ON stall_holders
  FOR SELECT USING (get_user_role(auth.uid()::uuid) = 'admin');
CREATE POLICY "Stall holders can update own record" ON stall_holders
  FOR UPDATE USING (user_id = auth.uid()::uuid);

-- PRODUCTS policies
CREATE POLICY "Anyone can read visible in-stock products" ON products
  FOR SELECT USING (is_visible = TRUE);
CREATE POLICY "Stall holders can manage own products" ON products
  FOR ALL USING (
    stall_holder_id IN (
      SELECT stall_holder_id FROM stall_holders WHERE user_id = auth.uid()::uuid
    )
  );

-- CART policies
CREATE POLICY "Customers can manage own cart" ON cart
  FOR ALL USING (
    customer_id IN (
      SELECT customer_id FROM customers WHERE user_id = auth.uid()::uuid
    )
  );

-- ORDERS policies
CREATE POLICY "Customers can read own orders" ON orders
  FOR SELECT USING (
    customer_id IN (
      SELECT customer_id FROM customers WHERE user_id = auth.uid()::uuid
    )
  );
CREATE POLICY "Stall holders can read own orders" ON orders
  FOR SELECT USING (
    stall_holder_id IN (
      SELECT stall_holder_id FROM stall_holders WHERE user_id = auth.uid()::uuid
    )
  );
CREATE POLICY "Admins can read all orders" ON orders
  FOR SELECT USING (get_user_role(auth.uid()::uuid) = 'admin');

-- KYC_SUBMISSIONS policies
CREATE POLICY "Stall holders can read own KYC" ON kyc_submissions
  FOR SELECT USING (
    stall_holder_id IN (
      SELECT stall_holder_id FROM stall_holders WHERE user_id = auth.uid()::uuid
    )
  );
CREATE POLICY "Admins can read all KYC submissions" ON kyc_submissions
  FOR SELECT USING (get_user_role(auth.uid()::uuid) = 'admin');
CREATE POLICY "Admins can update KYC submissions" ON kyc_submissions
  FOR UPDATE USING (get_user_role(auth.uid()::uuid) = 'admin');

-- NOTIFICATIONS policies
CREATE POLICY "Users can read own notifications" ON notifications
  FOR SELECT USING (user_id = auth.uid()::uuid);
CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (user_id = auth.uid()::uuid);

-- RATINGS policies
CREATE POLICY "Anyone can read ratings" ON ratings FOR SELECT USING (TRUE);
CREATE POLICY "Customers can insert own ratings" ON ratings
  FOR INSERT WITH CHECK (
    customer_id IN (
      SELECT customer_id FROM customers WHERE user_id = auth.uid()::uuid
    )
  );

-- PROMOS policies
CREATE POLICY "Anyone can read active promos" ON promos
  FOR SELECT USING (is_active = TRUE);
CREATE POLICY "Stall holders can manage own promos" ON promos
  FOR ALL USING (
    stall_holder_id IN (
      SELECT stall_holder_id FROM stall_holders WHERE user_id = auth.uid()::uuid
    )
  );

-- SALES_SUMMARY policies
CREATE POLICY "Stall holders can read own sales" ON sales_summary
  FOR SELECT USING (
    stall_holder_id IN (
      SELECT stall_holder_id FROM stall_holders WHERE user_id = auth.uid()::uuid
    )
  );
CREATE POLICY "Admins can read all sales" ON sales_summary
  FOR SELECT USING (get_user_role(auth.uid()::uuid) = 'admin');

-- DELIVERY_RATE_CONFIG policies
CREATE POLICY "Anyone can read delivery rate config" ON delivery_rate_config
  FOR SELECT USING (TRUE);
CREATE POLICY "Admins can manage delivery rate config" ON delivery_rate_config
  FOR ALL USING (get_user_role(auth.uid()::uuid) = 'admin');

-- APP_SETTINGS policies
CREATE POLICY "Anyone can read app settings" ON app_settings
  FOR SELECT USING (TRUE);
CREATE POLICY "Admins can manage app settings" ON app_settings
  FOR ALL USING (get_user_role(auth.uid()::uuid) = 'admin');

-- ADMIN_ACTIVITY_LOGS policies
CREATE POLICY "Admins can read activity logs" ON admin_activity_logs
  FOR SELECT USING (get_user_role(auth.uid()::uuid) = 'admin');
CREATE POLICY "Admins can insert activity logs" ON admin_activity_logs
  FOR INSERT WITH CHECK (get_user_role(auth.uid()::uuid) = 'admin');

-- SYSTEM_ANNOUNCEMENTS policies
CREATE POLICY "Anyone can read announcements" ON system_announcements
  FOR SELECT USING (TRUE);
CREATE POLICY "Admins can manage announcements" ON system_announcements
  FOR ALL USING (get_user_role(auth.uid()::uuid) = 'admin');
