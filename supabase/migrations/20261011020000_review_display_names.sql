-- Expose only the public review fields and display name, not customer contact data.
CREATE OR REPLACE FUNCTION public.read_stall_reviews(p_stall_id text)
RETURNS TABLE (rating_id text, stall_holder_id text, customer_id text,
  customer_name text, score integer, comment text, created_at timestamptz, order_id text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT r.rating_id::text, r.stall_holder_id::text, r.customer_id::text,
    coalesce(nullif(trim(u.full_name), ''), 'Customer'), r.score::integer,
    r.comment, r.created_at::timestamptz, r.order_id::text
  FROM public.ratings r
  LEFT JOIN public.customers c ON c.customer_id = r.customer_id
  LEFT JOIN public.users u ON u.user_id = c.user_id
  WHERE r.stall_holder_id::text = p_stall_id
  ORDER BY r.created_at DESC, r.rating_id
$$;
REVOKE ALL ON FUNCTION public.read_stall_reviews(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.read_stall_reviews(text) TO anon, authenticated;
