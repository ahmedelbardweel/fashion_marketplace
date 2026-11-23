-- Migration 036: Persist customer body measurement profiles in Supabase
-- Private per-user storage with strict Row Level Security so saved measurements
-- survive clearing app data, reinstalling, or signing in on another device.

create table if not exists public.user_body_measurements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active_profile_id text,
  profiles jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.user_body_measurements enable row level security;

drop policy if exists "Users can read own body measurements" on public.user_body_measurements;
create policy "Users can read own body measurements"
  on public.user_body_measurements
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own body measurements" on public.user_body_measurements;
create policy "Users can insert own body measurements"
  on public.user_body_measurements
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own body measurements" on public.user_body_measurements;
create policy "Users can update own body measurements"
  on public.user_body_measurements
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own body measurements" on public.user_body_measurements;
create policy "Users can delete own body measurements"
  on public.user_body_measurements
  for delete
  to authenticated
  using (auth.uid() = user_id);
