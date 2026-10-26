CREATE OR REPLACE FUNCTION public.save_customer_address(
  p_uid text,
  p_address jsonb,
  p_delete boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  customer_key text;
  address_key uuid;
  saved public.customer_addresses%ROWTYPE;
BEGIN
  PERFORM 1
  FROM users
  WHERE user_id = p_uid AND NOT coalesce(is_blocked, false)
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active account required'; END IF;

  SELECT customer_id INTO customer_key
  FROM customers
  WHERE user_id = p_uid
  LIMIT 1;
  IF customer_key IS NULL THEN
    INSERT INTO customers(user_id)
    VALUES (p_uid)
    RETURNING customer_id INTO customer_key;
  END IF;

  IF p_address->>'addressId' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    address_key := (p_address->>'addressId')::uuid;
    IF NOT EXISTS (
      SELECT 1 FROM customer_addresses
      WHERE address_id = address_key AND customer_id = customer_key
    ) THEN
      RAISE EXCEPTION 'Address not found';
    END IF;
  END IF;

  IF p_delete THEN
    IF address_key IS NULL THEN RAISE EXCEPTION 'Address ID required'; END IF;
    DELETE FROM customer_addresses
    WHERE address_id = address_key AND customer_id = customer_key;
    SELECT * INTO saved FROM customer_addresses
    WHERE customer_id = customer_key
    ORDER BY is_default DESC, address_id
    LIMIT 1;
    IF FOUND THEN
      UPDATE customer_addresses SET is_default = true
      WHERE address_id = saved.address_id;
    END IF;
  ELSE
    -- A missing ID means this is a new address, even when its label matches
    -- another saved address. Existing addresses are updated by ID only.
    address_key := coalesce(address_key, gen_random_uuid());
    UPDATE customer_addresses SET is_default = false
    WHERE customer_id = customer_key;
    INSERT INTO customer_addresses(
      address_id, customer_id, label, full_address, latitude, longitude,
      landmarks, is_default, street_address, contact_name, icon_code_point
    )
    VALUES (
      address_key, customer_key, p_address->>'label',
      p_address->>'fullAddress',
      (p_address->>'latitude')::double precision,
      (p_address->>'longitude')::double precision,
      p_address->>'landmarks', true,
      coalesce(p_address->>'streetAddress', ''),
      coalesce(p_address->>'contactName', ''),
      (p_address->>'iconCodePoint')::integer
    )
    ON CONFLICT (address_id) DO UPDATE SET
      label = EXCLUDED.label,
      full_address = EXCLUDED.full_address,
      latitude = EXCLUDED.latitude,
      longitude = EXCLUDED.longitude,
      landmarks = EXCLUDED.landmarks,
      is_default = true,
      street_address = EXCLUDED.street_address,
      contact_name = EXCLUDED.contact_name,
      icon_code_point = EXCLUDED.icon_code_point
    RETURNING * INTO saved;
  END IF;

  UPDATE customers
  SET saved_address = saved.full_address,
      latitude = saved.latitude,
      longitude = saved.longitude,
      address_landmarks = saved.landmarks
  WHERE customer_id = customer_key;
  RETURN to_jsonb(saved);
END;
$$;

REVOKE ALL ON FUNCTION public.save_customer_address(text, jsonb, boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.save_customer_address(text, jsonb, boolean)
  TO service_role;
