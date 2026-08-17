-- PalengkeGo — Supabase `recipes` table (public read-only content store).
--
-- Supabase's job in this stack is the recipe catalog the app recommends from
-- (see lib/features/recipes/data/supabase_recipe_repository.dart for the exact
-- row contract this migration must satisfy):
--
--   id, title, category, "time", difficulty, image_url,
--   serving (text|null), calories (text|null),
--   background_color (bigint ARGB|null),
--   ingredients (jsonb [{name, description, image_url?}]),
--   steps (jsonb [{title, description}])
--
-- Apply with:  supabase db push        (from repo root, after `supabase link`)
-- or paste into the Supabase SQL editor. The app reads this table with the
-- ANON key — RLS below is what makes that safe.

create table if not exists public.recipes (
  id               bigint generated always as identity primary key,
  title            text not null,
  category         text not null default '',
  "time"           text not null default '',
  difficulty       text not null default '',
  image_url        text not null default '',
  serving          text,
  calories         text,
  background_color bigint, -- int ARGB, e.g. 4292932350 (0xFFE0F2FE)
  ingredients      jsonb,  -- [{name, description, image_url?}]
  steps            jsonb,  -- [{title, description}]
  created_at       timestamptz not null default now()
);

comment on table public.recipes is
  'Recipe catalog consumed by PalengkeGo (public read-only, anon key).';
comment on column public.recipes.background_color is
  'ARGB int matching the Flutter Color(int) constructor (0xFFE0F2FE -> 4292932350).';
comment on column public.recipes.ingredients is
  '[{ "name": "…", "description": "…", "image_url": "…" }]';
comment on column public.recipes.steps is
  '[{ "title": "…", "description": "…" }]';

-- The Flutter app orders by `id` (SupabaseRecipeRepository .order('id')) and
-- treats the first row as the featured recipe — the identity sequence
-- guarantees stable, ascending ids for new content.
alter table public.recipes enable row level security;

-- Public read: the app's anon key reads the whole catalog.
create policy "recipes are publicly readable"
  on public.recipes
  for select
  using (true);

-- No client writes: content is managed out-of-band (dashboard/migration).
-- RLS already denies everything without policies; these make the intent
-- explicit and self-documenting.
create policy "no client insert"
  on public.recipes
  for insert
  with check (false);

create policy "no client update"
  on public.recipes
  for update
  using (false);

create policy "no client delete"
  on public.recipes
  for delete
  using (false);

-- One documentation row (matches MockRecipeRepository's first recipe, so
-- Supabase mode and mock mode agree on the featured recipe). Delete it before
-- seeding your real catalog, or keep it as the baseline.
insert into public.recipes (
  title, category, "time", difficulty, image_url,
  serving, calories, background_color, ingredients, steps
) values (
  'Sinigang na Hipon',
  'Seafood',
  '30 min',
  'Easy',
  'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=400&h=250&fit=crop',
  '3-4 servings',
  '280 kcal',
  4292932350, -- 0xFFE0F2FE
  '[
    {"name":"Shrimp","description":"500g fresh head-on shrimp"},
    {"name":"Tamarind","description":"1 pack sinigang mix or fresh tamarind pulp"},
    {"name":"Tomato","description":"2 large, quartered"},
    {"name":"Onion","description":"1 medium, sliced"},
    {"name":"Radish","description":"1 medium, sliced"},
    {"name":"Chili","description":"2 pieces siling haba"},
    {"name":"Kangkong","description":"1 bunch water spinach"}
  ]'::jsonb,
  '[
    {"title":"Boil Aromatics","description":"In a pot, bring water to a boil with tomatoes and onions until soft."},
    {"title":"Add Vegetables & Sourness","description":"Add sliced radish and tamarind mix. Simmer for 5 minutes."},
    {"title":"Cook Shrimp","description":"Gently add the shrimp and long green chilis. Cook for 3-4 minutes until shrimp turns pink."},
    {"title":"Finish with Greens","description":"Toss in the kangkong leaves, turn off heat, cover and let wilt for 2 minutes before serving."}
  ]'::jsonb
);
