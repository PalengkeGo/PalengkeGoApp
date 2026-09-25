-- USERS
CREATE TABLE users (
  user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL,
  phone_number TEXT UNIQUE,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT,
  role TEXT NOT NULL CHECK (role IN ('customer', 'stallholder', 'admin')),
  profile_photo TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  is_blocked BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- CUSTOMERS
CREATE TABLE customers (
  customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  saved_address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  address_landmarks TEXT
);

-- CUSTOMER_ADDRESSES
CREATE TABLE customer_addresses (
  address_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
  label TEXT CHECK (label IN ('home', 'office', 'other')),
  full_address TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  landmarks TEXT,
  is_default BOOLEAN DEFAULT FALSE
);

-- STALL_HOLDERS
CREATE TABLE stall_holders (
  stall_holder_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  stall_name TEXT NOT NULL,
  stall_number TEXT NOT NULL,
  floor_number TEXT NOT NULL,
  section TEXT,
  category TEXT NOT NULL CHECK (category IN ('Fresh Fish', 'Dried Fish', 'Fruits', 'Meat', 'Chicken', 'Vegetables', 'Maritatas', 'Sari-Sari')),
  is_open BOOLEAN DEFAULT FALSE,
  is_kyc_approved BOOLEAN DEFAULT FALSE,
  is_blocked BOOLEAN DEFAULT FALSE,
  kyc_status TEXT DEFAULT 'pending' CHECK (kyc_status IN ('pending', 'approved', 'rejected')),
  average_rating DOUBLE PRECISION DEFAULT 0,
  total_ratings INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- STALL_HOLDER_DELIVERY_SETTINGS
CREATE TABLE stall_holder_delivery_settings (
  delivery_setting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stall_holder_id UUID NOT NULL REFERENCES stall_holders(stall_holder_id) ON DELETE CASCADE,
  is_available_to_deliver BOOLEAN DEFAULT FALSE,
  preferred_third_party_booking TEXT CHECK (preferred_third_party_booking IN ('lalamove', 'grabexpress', 'none'))
);

-- STALL_HOLDER_SCHEDULE
CREATE TABLE stall_holder_schedule (
  schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stall_holder_id UUID NOT NULL REFERENCES stall_holders(stall_holder_id) ON DELETE CASCADE,
  day_of_week TEXT NOT NULL CHECK (day_of_week IN ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')),
  opening_time TIME,
  closing_time TIME,
  is_closed BOOLEAN DEFAULT FALSE
);

-- STALL_HOLDER_RATINGS_SUMMARY
CREATE TABLE stall_holder_ratings_summary (
  summary_rating_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stall_holder_id UUID NOT NULL REFERENCES stall_holders(stall_holder_id) ON DELETE CASCADE,
  average_score DOUBLE PRECISION DEFAULT 0,
  total_ratings INTEGER DEFAULT 0,
  count_5_star INTEGER DEFAULT 0,
  count_4_star INTEGER DEFAULT 0,
  count_3_star INTEGER DEFAULT 0,
  count_2_star INTEGER DEFAULT 0,
  count_1_star INTEGER DEFAULT 0,
  last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- ADMINS
CREATE TABLE admins (
  admin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  office_title TEXT,
  email TEXT NOT NULL
);

-- ADMIN_ACTIVITY_LOGS
CREATE TABLE admin_activity_logs (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES admins(admin_id),
  action_type TEXT NOT NULL CHECK (action_type IN ('approved_kyc', 'rejected_kyc', 'blocked_user', 'unblocked_user', 'exported_report')),
  target_id TEXT,
  target_type TEXT CHECK (target_type IN ('user', 'stallholder', 'kyc', 'report')),
  remarks TEXT,
  performed_at TIMESTAMPTZ DEFAULT NOW()
);

-- KYC_SUBMISSIONS
CREATE TABLE kyc_submissions (
  kyc_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stall_holder_id UUID NOT NULL REFERENCES stall_holders(stall_holder_id),
  mayor_permit_url TEXT NOT NULL,
  sanitary_permit_url TEXT NOT NULL,
  fire_certification_url TEXT NOT NULL,
  market_clearance_url TEXT NOT NULL,
  mayor_permit_number TEXT,
  sanitary_permit_number TEXT,
  fire_cert_number TEXT,
  market_clearance_number TEXT,
  valid_id_photo_url TEXT NOT NULL,
  selfie_url TEXT NOT NULL,
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by UUID REFERENCES admins(admin_id),
  reviewed_at TIMESTAMPTZ,
  rejection_reason TEXT
);

-- PRODUCTS
CREATE TABLE products (
  product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stall_holder_id UUID NOT NULL REFERENCES stall_holders(stall_holder_id) ON DELETE CASCADE,
  product_name TEXT NOT NULL,
  category_tag TEXT NOT NULL CHECK (category_tag IN ('Fresh Fish', 'Dried Fish', 'Fruits', 'Meat', 'Chicken', 'Vegetables', 'Maritatas', 'Sari-Sari')),
  price_per_kg DOUBLE PRECISION,
  price_per_piece DOUBLE PRECISION,
  unit TEXT NOT NULL CHECK (unit IN ('kg', 'piece')),
  image_url TEXT,
  is_in_stock BOOLEAN DEFAULT TRUE,
  is_visible BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- PRODUCT_CATEGORY_CROSS_TAG
CREATE TABLE product_category_cross_tag (
  cross_tag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  stall_holder_id UUID NOT NULL REFERENCES stall_holders(stall_holder_id),
  cross_category_tag TEXT DEFAULT 'Vegetables',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- CART
CREATE TABLE cart (
  cart_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
  stall_holder_id UUID NOT NULL REFERENCES stall_holders(stall_holder_id),
  product_id UUID NOT NULL REFERENCES products(product_id),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  added_at TIMESTAMPTZ DEFAULT NOW()
);

-- ORDERS
CREATE TABLE orders (
  order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(customer_id),
  stall_holder_id UUID NOT NULL REFERENCES stall_holders(stall_holder_id),
  fulfillment_type TEXT NOT NULL CHECK (fulfillment_type IN ('pickup', 'delivery')),
  delivery_address TEXT,
  delivery_latitude DOUBLE PRECISION,
  delivery_longitude DOUBLE PRECISION,
  distance_km DOUBLE PRECISION,
  delivery_fee DOUBLE PRECISION DEFAULT 0,
  subtotal DOUBLE PRECISION NOT NULL,
  total_amount DOUBLE PRECISION NOT NULL,
  payment_method TEXT NOT NULL CHECK (payment_method IN ('gcash', 'cod')),
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed')),
  order_status TEXT DEFAULT 'pending' CHECK (order_status IN ('pending', 'confirmed', 'preparing', 'ready', 'out_for_delivery', 'delivered', 'cancelled', 'rejected')),
  estimated_ready_time TIMESTAMPTZ,
  cancellation_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ORDER_ITEMS
CREATE TABLE order_items (
  order_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(product_id),
  product_name TEXT NOT NULL,
  category_tag TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  price_at_order DOUBLE PRECISION NOT NULL,
  subtotal DOUBLE PRECISION NOT NULL
);

-- ORDER_STATUS_HISTORY
CREATE TABLE order_status_history (
  history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
  previous_status TEXT,
  new_status TEXT NOT NULL,
  changed_by UUID REFERENCES users(user_id),
  changed_at TIMESTAMPTZ DEFAULT NOW(),
  remarks TEXT
);

-- RATINGS
CREATE TABLE ratings (
  rating_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(customer_id),
  stall_holder_id UUID NOT NULL REFERENCES stall_holders(stall_holder_id),
  order_id UUID NOT NULL UNIQUE REFERENCES orders(order_id),
  score INTEGER NOT NULL CHECK (score BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- PROMOS
CREATE TABLE promos (
  promo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stall_holder_id UUID NOT NULL REFERENCES stall_holders(stall_holder_id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);

-- NOTIFICATIONS
CREATE TABLE notifications (
  notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('order_update', 'flash_sale', 'kyc_update', 'new_order', 'system_announcement')),
  reference_id TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- FLASH_SALE_NOTIFICATIONS
CREATE TABLE flash_sale_notifications (
  flash_notif_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_id UUID NOT NULL REFERENCES promos(promo_id),
  notification_id UUID NOT NULL REFERENCES notifications(notification_id),
  sent_at TIMESTAMPTZ DEFAULT NOW()
);

-- SYSTEM_ANNOUNCEMENTS
CREATE TABLE system_announcements (
  announcement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES admins(admin_id),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  target_audience TEXT NOT NULL CHECK (target_audience IN ('all', 'customers', 'stallholders')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);

-- SALES_SUMMARY
CREATE TABLE sales_summary (
  summary_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stall_holder_id UUID NOT NULL REFERENCES stall_holders(stall_holder_id),
  date DATE NOT NULL,
  total_orders INTEGER DEFAULT 0,
  total_revenue DOUBLE PRECISION DEFAULT 0,
  total_items_sold INTEGER DEFAULT 0
);

-- REPORT_EXPORTS
CREATE TABLE report_exports (
  export_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  exported_by UUID NOT NULL REFERENCES users(user_id),
  export_type TEXT NOT NULL CHECK (export_type IN ('pdf', 'excel')),
  report_scope TEXT NOT NULL CHECK (report_scope IN ('stall_holder', 'system_wide')),
  date_range_start DATE,
  date_range_end DATE,
  exported_at TIMESTAMPTZ DEFAULT NOW()
);

-- DELIVERY_RATE_CONFIG
CREATE TABLE delivery_rate_config (
  config_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  base_rate DOUBLE PRECISION NOT NULL DEFAULT 30.00,
  rate_per_km DOUBLE PRECISION NOT NULL DEFAULT 10.00,
  effective_date DATE NOT NULL,
  set_by UUID NOT NULL REFERENCES admins(admin_id)
);

-- APP_SETTINGS
CREATE TABLE app_settings (
  setting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  max_delivery_radius_km DOUBLE PRECISION DEFAULT 10.0,
  cancellation_window_minutes INTEGER DEFAULT 5,
  maintenance_mode BOOLEAN DEFAULT FALSE,
  updated_by UUID REFERENCES admins(admin_id),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- SEARCH_LOGS
CREATE TABLE search_logs (
  search_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(customer_id),
  search_query TEXT NOT NULL,
  searched_at TIMESTAMPTZ DEFAULT NOW(),
  results_count INTEGER DEFAULT 0
);

-- INDEXES
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_stall_holder_id ON orders(stall_holder_id);
CREATE INDEX idx_orders_status ON orders(order_status);
CREATE INDEX idx_products_stall_holder_id ON products(stall_holder_id);
CREATE INDEX idx_products_category_tag ON products(category_tag);
CREATE INDEX idx_cart_customer_id ON cart(customer_id);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_ratings_stall_holder_id ON ratings(stall_holder_id);
CREATE INDEX idx_kyc_submissions_status ON kyc_submissions(status);
CREATE INDEX idx_sales_summary_stall_holder_id ON sales_summary(stall_holder_id);
CREATE INDEX idx_search_logs_customer_id ON search_logs(customer_id);
