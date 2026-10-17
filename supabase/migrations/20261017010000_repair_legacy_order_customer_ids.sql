-- Older orders stored the Firebase UID in customer_id instead of the
-- customer's canonical customers.customer_id. Repair only unambiguous links.
WITH unique_customer_ids AS (
  SELECT user_id, min(customer_id) AS customer_id
  FROM public.customers
  GROUP BY user_id
  HAVING count(*) = 1
)
UPDATE public.orders AS o
SET customer_id = c.customer_id
FROM unique_customer_ids AS c
WHERE o.customer_id = c.user_id
  AND NOT EXISTS (
    SELECT 1
    FROM public.customers AS existing
    WHERE existing.customer_id = o.customer_id
  );
