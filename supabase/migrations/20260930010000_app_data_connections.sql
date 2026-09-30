-- Apply with the matching Edge Functions and Flutter build.
-- Existing anonymous RLS policies require a separate Firebase/RLS hardening rollout.
ALTER TABLE public.order_items ALTER COLUMN quantity TYPE double precision;
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS unit text NOT NULL DEFAULT 'kg';
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS image text NOT NULL DEFAULT '';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS service_fee double precision NOT NULL DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS refund_request_reason text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS refund_requested_at timestamptz;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS refunded_amount double precision NOT NULL DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS refund_id text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_payment_status_check
  CHECK (payment_status IN ('pending','paid','failed','refundRequested','refunded'));
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_payment_method_check
  CHECK (payment_method IN ('cod','cop','gcash','maya','paymaya','card'));

-- Only verified Firebase Edge Functions may call these transaction functions.
CREATE OR REPLACE FUNCTION public.place_market_orders(p_uid text, p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SET search_path = public AS $$
DECLARE
  customer_key text;
  group_row record;
  item_row record;
  product_row public.products%ROWTYPE;
  stall_row public.stall_holders%ROWTYPE;
  order_row public.orders%ROWTYPE;
  order_key text;
  day_prefix text := to_char(now() AT TIME ZONE 'Asia/Manila', 'YYMMDD');
  next_number integer;
  subtotal_value double precision;
  unit_price double precision;
  item_total double precision;
  item_rows jsonb;
  result_rows jsonb := '[]'::jsonb;
  fees jsonb := p_data->'fees';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE user_id=p_uid AND role='customer' AND NOT coalesce(is_blocked,false)) THEN
    RAISE EXCEPTION 'An active customer account is required';
  END IF;
  IF jsonb_typeof(p_data->'lineItemsByStall') IS DISTINCT FROM 'object'
     OR p_data->'lineItemsByStall' = '{}'::jsonb THEN
    RAISE EXCEPTION 'Your cart is empty';
  END IF;
  -- ponytail: one checkout lock serializes checkouts; replace with a daily
  -- sequence plus ordered product locks if checkout throughput grows.
  PERFORM pg_advisory_xact_lock(26093001);
  SELECT customer_id INTO customer_key FROM customers WHERE user_id=p_uid LIMIT 1;
  IF customer_key IS NULL THEN
    INSERT INTO customers(user_id) VALUES(p_uid) RETURNING customer_id INTO customer_key;
  END IF;
  SELECT coalesce(max(split_part(order_id,'-',2)::integer),0)+1 INTO next_number
    FROM orders WHERE order_id ~ ('^' || day_prefix || '-[0-9]+$');
  FOR group_row IN SELECT key, value FROM jsonb_each(p_data->'lineItemsByStall') ORDER BY key LOOP
    SELECT * INTO STRICT stall_row FROM stall_holders WHERE stall_holder_id=group_row.key;
    IF NOT coalesce(stall_row.is_open,false) OR coalesce(stall_row.is_blocked,false) THEN
      RAISE EXCEPTION 'This stall is not accepting orders';
    END IF;
    IF jsonb_typeof(group_row.value) <> 'array' OR jsonb_array_length(group_row.value)=0 THEN
      RAISE EXCEPTION 'Order items are required';
    END IF;
    order_key := day_prefix || '-' || lpad(next_number::text, greatest(2,length(next_number::text)), '0');
    next_number := next_number+1;
    subtotal_value := 0;
    item_rows := '[]'::jsonb;
    FOR item_row IN
      SELECT x->>'productId' AS product_id, sum((x->>'quantity')::double precision) AS quantity
      FROM jsonb_array_elements(group_row.value) x GROUP BY x->>'productId' ORDER BY x->>'productId'
    LOOP
      SELECT * INTO STRICT product_row FROM products WHERE product_id=item_row.product_id FOR UPDATE;
      IF product_row.stall_holder_id <> group_row.key OR NOT coalesce(product_row.is_visible,false)
         OR NOT coalesce(product_row.is_in_stock,false) THEN RAISE EXCEPTION 'Product is unavailable'; END IF;
      IF item_row.quantity IS NULL OR item_row.quantity <= 0 OR item_row.quantity::text IN ('NaN','Infinity','-Infinity')
         OR product_row.stock_quantity IS NULL OR item_row.quantity > product_row.stock_quantity THEN
        RAISE EXCEPTION 'Invalid quantity or insufficient stock';
      END IF;
      IF product_row.unit IN ('piece','pc') AND item_row.quantity <> trunc(item_row.quantity) THEN
        RAISE EXCEPTION 'Piece quantities must be whole numbers';
      END IF;
      unit_price := CASE WHEN product_row.unit IN ('piece','pc') THEN product_row.price_per_piece ELSE product_row.price_per_kg END;
      IF unit_price IS NULL OR unit_price < 0 OR unit_price::text IN ('NaN','Infinity','-Infinity') THEN
        RAISE EXCEPTION 'Invalid product price';
      END IF;
      unit_price := round((unit_price * (1-least(100,greatest(0,coalesce(product_row.discount_percentage,0)))/100))::numeric,2);
      item_total := round((unit_price * item_row.quantity)::numeric,2);
      subtotal_value := subtotal_value + item_total;
      item_rows := item_rows || jsonb_build_array(jsonb_build_object(
        'order_id',order_key,'product_id',product_row.product_id,'product_name',product_row.product_name,
        'category_tag',product_row.category_tag,'quantity',item_row.quantity,'price_at_order',unit_price,
        'subtotal',item_total,'unit',product_row.unit,'image',coalesce(product_row.image_url,'')));
      UPDATE products SET stock_quantity=stock_quantity-item_row.quantity,
        is_in_stock=(stock_quantity-item_row.quantity)>0, updated_at=now() WHERE product_id=product_row.product_id;
    END LOOP;
    INSERT INTO orders(order_id,customer_id,stall_holder_id,fulfillment_type,delivery_address,
      delivery_latitude,delivery_longitude,distance_km,delivery_fee,service_fee,priority_fee,is_priority,
      subtotal,total_amount,payment_method,customer_name,customer_phone,notes)
    VALUES(order_key,customer_key,group_row.key,CASE WHEN (p_data->>'isPickup')::boolean THEN 'pickup' ELSE 'delivery' END,
      p_data->>'deliveryAddress',(p_data->>'deliveryLatitude')::double precision,(p_data->>'deliveryLongitude')::double precision,
      (fees->>'deliveryDistanceKm')::double precision,(fees->>'deliveryFee')::double precision,
      (fees->>'serviceFee')::double precision,(fees->>'priorityFee')::double precision,
      (fees->>'priorityFee')::double precision>0,subtotal_value,
      subtotal_value+(fees->>'deliveryFee')::double precision+(fees->>'serviceFee')::double precision+(fees->>'priorityFee')::double precision,
      p_data->>'paymentMethod',p_data->>'customerName',p_data->>'customerPhone',p_data->'vendorNotes'->>group_row.key)
    RETURNING * INTO order_row;
    INSERT INTO order_items(order_id,product_id,product_name,category_tag,quantity,price_at_order,subtotal,unit,image)
      SELECT x.order_id,x.product_id,x.product_name,x.category_tag,x.quantity,x.price_at_order,x.subtotal,x.unit,x.image
      FROM jsonb_to_recordset(item_rows) AS x(order_id text,product_id text,product_name text,category_tag text,
        quantity double precision,price_at_order double precision,subtotal double precision,unit text,image text);
    INSERT INTO order_status_history(order_id,new_status,changed_by,remarks) VALUES(order_key,'pending',p_uid,'Order placed');
    result_rows := result_rows || jsonb_build_array(to_jsonb(order_row) || jsonb_build_object(
      'items',item_rows,'stall',to_jsonb(stall_row),'customer_uid',p_uid));
  END LOOP;
  RETURN result_rows;
END $$;
REVOKE ALL ON FUNCTION public.place_market_orders(text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.place_market_orders(text,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.save_market_stall(p_uid text, p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SET search_path = public AS $$
DECLARE stall_row public.stall_holders%ROWTYPE; schedule_row jsonb;
BEGIN
  SELECT * INTO STRICT stall_row FROM stall_holders WHERE user_id=p_uid FOR UPDATE;
  UPDATE stall_holders SET stall_name=p_data->>'stall_name', description=p_data->>'description',
    category=p_data->>'category', is_open=(p_data->>'is_open')::boolean,
    banner_image_url=p_data->>'banner_image_url', avatar_image_url=p_data->>'avatar_image_url',
    thumbnail_url=p_data->>'thumbnail_url' WHERE stall_holder_id=stall_row.stall_holder_id
    RETURNING * INTO stall_row;
  IF p_data ? 'schedule' THEN
    DELETE FROM stall_holder_schedule WHERE stall_holder_id=stall_row.stall_holder_id;
    FOR schedule_row IN SELECT value FROM jsonb_array_elements(p_data->'schedule') LOOP
      INSERT INTO stall_holder_schedule(stall_holder_id,day_of_week,opening_time,closing_time,is_closed)
      VALUES(stall_row.stall_holder_id,schedule_row->>'name',(schedule_row->>'openTime')::time,
        (schedule_row->>'closeTime')::time,NOT (schedule_row->>'isOpen')::boolean);
    END LOOP;
  END IF;
  RETURN to_jsonb(stall_row);
END $$;
REVOKE ALL ON FUNCTION public.save_market_stall(text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.save_market_stall(text,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.refresh_stall_rating() RETURNS trigger
LANGUAGE plpgsql SET search_path=public AS $$
DECLARE stall_key text := CASE WHEN TG_OP='DELETE' THEN OLD.stall_holder_id ELSE NEW.stall_holder_id END;
BEGIN
  -- Lock before aggregating so concurrent ratings cannot overwrite a newer count.
  PERFORM 1 FROM stall_holders WHERE stall_holder_id=stall_key FOR UPDATE;
  UPDATE stall_holders SET average_rating=(SELECT coalesce(avg(score),0) FROM ratings WHERE stall_holder_id=stall_key),
    total_ratings=(SELECT count(*) FROM ratings WHERE stall_holder_id=stall_key) WHERE stall_holder_id=stall_key;
  RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS ratings_refresh_stall ON public.ratings;
CREATE TRIGGER ratings_refresh_stall AFTER INSERT OR UPDATE OR DELETE ON public.ratings
FOR EACH ROW EXECUTE FUNCTION public.refresh_stall_rating();

CREATE OR REPLACE FUNCTION public.transition_market_order(p_uid text,p_order_id text,p_status text,
  p_remarks text DEFAULT NULL,p_estimated_ready_time timestamptz DEFAULT NULL,p_customer_cancel boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SET search_path=public AS $$
DECLARE o public.orders%ROWTYPE; owner_key text; customer_key text; previous text;
BEGIN
  SELECT * INTO STRICT o FROM orders WHERE order_id=p_order_id FOR UPDATE;
  SELECT user_id INTO owner_key FROM stall_holders WHERE stall_holder_id=o.stall_holder_id;
  SELECT user_id INTO customer_key FROM customers WHERE customer_id=o.customer_id;
  IF p_customer_cancel THEN
    IF customer_key IS DISTINCT FROM p_uid THEN RAISE EXCEPTION 'Not your order'; END IF;
    IF o.order_status <> 'pending' OR p_status <> 'cancelled' THEN RAISE EXCEPTION 'Only pending orders can be cancelled'; END IF;
    IF now()>o.created_at+interval '5 minutes' THEN RAISE EXCEPTION 'Cancellation window has expired'; END IF;
  ELSE
    IF owner_key IS DISTINCT FROM p_uid AND NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_uid AND role='admin') THEN
      RAISE EXCEPTION 'Only the stall owner can update this order';
    END IF;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_uid AND NOT coalesce(is_blocked,false)) THEN
    RAISE EXCEPTION 'Active account required';
  END IF;
  previous := o.order_status;
  IF previous IN ('delivered','cancelled','rejected') THEN RAISE EXCEPTION 'Order is already complete'; END IF;
  IF p_status IS NULL OR NOT (p_status=previous OR
    (previous='pending' AND p_status IN ('confirmed','preparing','cancelled','rejected')) OR
    (previous='confirmed' AND p_status IN ('preparing','cancelled')) OR
    (previous='preparing' AND p_status IN ('ready','cancelled')) OR
    (previous='ready' AND p_status IN ('out_for_delivery','delivered','cancelled')) OR
    (previous='out_for_delivery' AND p_status IN ('delivered','cancelled'))) THEN
    RAISE EXCEPTION 'Invalid order status transition';
  END IF;
  IF p_status='out_for_delivery' AND o.fulfillment_type='pickup' THEN RAISE EXCEPTION 'Pickup orders cannot be dispatched'; END IF;
  UPDATE orders SET order_status=p_status,updated_at=now(),
    estimated_ready_time=coalesce(p_estimated_ready_time,estimated_ready_time),
    cancellation_reason=CASE WHEN p_status IN ('cancelled','rejected') THEN p_remarks ELSE cancellation_reason END,
    payment_status=CASE WHEN p_status='delivered' AND payment_method IN ('cod','cop') THEN 'paid' ELSE payment_status END
    WHERE order_id=p_order_id;
  IF p_status IN ('cancelled','rejected') THEN
    UPDATE products p SET stock_quantity=coalesce(p.stock_quantity,0)+i.quantity, is_in_stock=true,updated_at=now()
      FROM (SELECT product_id,sum(quantity) AS quantity FROM order_items WHERE order_id=p_order_id GROUP BY product_id) i
      WHERE p.product_id=i.product_id;
  END IF;
  INSERT INTO order_status_history(order_id,previous_status,new_status,changed_by,remarks)
    VALUES(p_order_id,previous,p_status,p_uid,p_remarks);
END $$;
REVOKE ALL ON FUNCTION public.transition_market_order(text,text,text,text,timestamptz,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.transition_market_order(text,text,text,text,timestamptz,boolean) TO service_role;

CREATE OR REPLACE FUNCTION public.refund_market_order(p_uid text,p_order_id text,p_decision text,p_reason text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SET search_path=public AS $$
DECLARE o public.orders%ROWTYPE; owner_key text; customer_key text;
BEGIN
  SELECT * INTO STRICT o FROM orders WHERE order_id=p_order_id FOR UPDATE;
  IF NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_uid AND NOT coalesce(is_blocked,false)) THEN
    RAISE EXCEPTION 'Active account required';
  END IF;
  IF p_decision='request' THEN
    SELECT user_id INTO customer_key FROM customers WHERE customer_id=o.customer_id;
    IF customer_key IS DISTINCT FROM p_uid THEN RAISE EXCEPTION 'Not your order'; END IF;
    IF o.payment_status <> 'paid' THEN RAISE EXCEPTION 'Only paid orders can be refunded'; END IF;
    UPDATE orders SET payment_status='refundRequested',refund_request_reason=p_reason,
      refund_requested_at=now(),updated_at=now() WHERE order_id=p_order_id;
  ELSE
    SELECT user_id INTO owner_key FROM stall_holders WHERE stall_holder_id=o.stall_holder_id;
    IF owner_key IS DISTINCT FROM p_uid AND NOT EXISTS(SELECT 1 FROM users WHERE user_id=p_uid AND role='admin') THEN
      RAISE EXCEPTION 'Only the stall owner can process this refund';
    END IF;
    IF o.payment_status <> 'refundRequested' THEN RAISE EXCEPTION 'No pending refund request'; END IF;
    IF p_decision='decline' THEN
      UPDATE orders SET payment_status='paid',updated_at=now() WHERE order_id=p_order_id;
    ELSIF p_decision='approve' THEN
      -- Never pretend an online payment was refunded without payment-provider confirmation.
      IF o.payment_method NOT IN ('cod','cop') THEN RAISE EXCEPTION 'Online refunds require payment-provider processing'; END IF;
      UPDATE orders SET payment_status='refunded',refunded_amount=total_amount,updated_at=now() WHERE order_id=p_order_id;
    ELSE RAISE EXCEPTION 'Invalid refund decision'; END IF;
  END IF;
  INSERT INTO order_status_history(order_id,previous_status,new_status,changed_by,remarks)
    VALUES(p_order_id,o.order_status,o.order_status,p_uid,'Refund ' || p_decision || coalesce(': ' || p_reason,''));
END $$;
REVOKE ALL ON FUNCTION public.refund_market_order(text,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.refund_market_order(text,text,text,text) TO service_role;

ALTER TABLE public.customer_addresses ADD COLUMN IF NOT EXISTS street_address text NOT NULL DEFAULT '';
ALTER TABLE public.customer_addresses ADD COLUMN IF NOT EXISTS contact_name text NOT NULL DEFAULT '';
ALTER TABLE public.customer_addresses ADD COLUMN IF NOT EXISTS icon_code_point integer;
ALTER TABLE public.customer_addresses ALTER COLUMN latitude DROP NOT NULL;
ALTER TABLE public.customer_addresses ALTER COLUMN longitude DROP NOT NULL;
ALTER TABLE public.customer_addresses DROP CONSTRAINT IF EXISTS customer_addresses_label_check;
CREATE OR REPLACE FUNCTION public.save_customer_address(p_uid text,p_address jsonb,p_delete boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SET search_path=public AS $$
DECLARE customer_key text; address_key uuid; saved public.customer_addresses%ROWTYPE;
BEGIN
  PERFORM 1 FROM users WHERE user_id=p_uid AND NOT coalesce(is_blocked,false) FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active account required'; END IF;
  SELECT customer_id INTO customer_key FROM customers WHERE user_id=p_uid LIMIT 1;
  IF customer_key IS NULL THEN INSERT INTO customers(user_id) VALUES(p_uid) RETURNING customer_id INTO customer_key; END IF;
  IF p_address->>'addressId' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    address_key := (p_address->>'addressId')::uuid;
    IF NOT EXISTS(SELECT 1 FROM customer_addresses WHERE address_id=address_key AND customer_id=customer_key) THEN
      RAISE EXCEPTION 'Address not found';
    END IF;
  END IF;
  IF p_delete THEN
    IF address_key IS NULL THEN RAISE EXCEPTION 'Address ID required'; END IF;
    DELETE FROM customer_addresses WHERE address_id=address_key AND customer_id=customer_key;
    SELECT * INTO saved FROM customer_addresses WHERE customer_id=customer_key ORDER BY is_default DESC,address_id LIMIT 1;
    IF FOUND THEN UPDATE customer_addresses SET is_default=true WHERE address_id=saved.address_id; END IF;
  ELSE
    IF address_key IS NULL THEN
      SELECT address_id INTO address_key FROM customer_addresses WHERE customer_id=customer_key
        AND lower(label)=lower(p_address->>'label') LIMIT 1;
    END IF;
    address_key := coalesce(address_key,gen_random_uuid());
    UPDATE customer_addresses SET is_default=false WHERE customer_id=customer_key;
    INSERT INTO customer_addresses(address_id,customer_id,label,full_address,latitude,longitude,landmarks,is_default,
      street_address,contact_name,icon_code_point)
    VALUES(address_key,customer_key,p_address->>'label',p_address->>'fullAddress',
      (p_address->>'latitude')::double precision,(p_address->>'longitude')::double precision,p_address->>'landmarks',true,
      coalesce(p_address->>'streetAddress',''),coalesce(p_address->>'contactName',''),(p_address->>'iconCodePoint')::integer)
    ON CONFLICT(address_id) DO UPDATE SET label=EXCLUDED.label,full_address=EXCLUDED.full_address,
      latitude=EXCLUDED.latitude,longitude=EXCLUDED.longitude,landmarks=EXCLUDED.landmarks,is_default=true,
      street_address=EXCLUDED.street_address,contact_name=EXCLUDED.contact_name,icon_code_point=EXCLUDED.icon_code_point
    RETURNING * INTO saved;
  END IF;
  UPDATE customers SET saved_address=saved.full_address,latitude=saved.latitude,longitude=saved.longitude,
    address_landmarks=saved.landmarks WHERE customer_id=customer_key;
  RETURN to_jsonb(saved);
END $$;
REVOKE ALL ON FUNCTION public.save_customer_address(text,jsonb,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.save_customer_address(text,jsonb,boolean) TO service_role;

-- Public stall hours and reviews can be displayed without exposing customer profiles.
DROP POLICY IF EXISTS "Read stall hours" ON public.stall_holder_schedule;
CREATE POLICY "Read stall hours" ON public.stall_holder_schedule FOR SELECT TO anon,authenticated USING(true);
DROP POLICY IF EXISTS "Read stall reviews" ON public.ratings;
CREATE POLICY "Read stall reviews" ON public.ratings FOR SELECT TO anon,authenticated USING(true);
