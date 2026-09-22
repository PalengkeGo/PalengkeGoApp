-- Clean serving column so you don't have to manually delete "person"
-- Existing rows are "1 person" (text) — normalize to "1" for the 1-serving base.
-- Future inserts should use integer or text "1" without "person"; Dart now handles both.

-- 1) Normalize existing text values to just the number
UPDATE public.recipes
SET serving = regexp_replace(serving, '[^0-9]', '', 'g')
WHERE serving IS NOT NULL AND serving ~ '[^0-9]';

-- Ensure every row has a value
UPDATE public.recipes SET serving = '1' WHERE serving IS NULL OR serving = '';

-- 2) Keep column as text for now (so "1" stays readable), but make Dart robust.
-- If you want true integer, uncomment the next line (Dart already handles both):
-- ALTER TABLE public.recipes ALTER COLUMN serving TYPE integer USING serving::integer;
-- ALTER TABLE public.recipes ALTER COLUMN serving SET DEFAULT 1;
