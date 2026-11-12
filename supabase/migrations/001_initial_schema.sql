-- HUNOR App V1 database schema for Supabase/PostgreSQL
-- Run this migration in the Supabase SQL Editor.

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  rank text,
  workplace text,
  position text,
  phone text,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.skills (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.availability (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id) on delete cascade,
  status text not null check (status in ('available','vacation','sick','training','unavailable')),
  start_date date not null,
  end_date date,
  created_at timestamptz not null default now(),
  constraint availability_dates_valid check (end_date is null or end_date >= start_date)
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  location text,
  description text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint event_dates_valid check (ends_at is null or ends_at >= starts_at)
);

create table if not exists public.event_participants (
  event_id uuid not null references public.events(id) on delete cascade,
  member_id uuid not null references public.profiles(id) on delete cascade,
  response text not null default 'pending' check (response in ('pending','going','not_going')),
  responded_at timestamptz,
  primary key (event_id, member_id)
);

alter table public.profiles enable row level security;
alter table public.skills enable row level security;
alter table public.availability enable row level security;
alter table public.events enable row level security;
alter table public.event_participants enable row level security;

-- Authenticated HUNOR members can read the shared directory and calendar.
create policy "members can read profiles"
on public.profiles for select
to authenticated
using (true);

create policy "members can read skills"
on public.skills for select
to authenticated
using (true);

create policy "members can read availability"
on public.availability for select
to authenticated
using (true);

create policy "members can read events"
on public.events for select
to authenticated
using (true);

create policy "members can read event participants"
on public.event_participants for select
to authenticated
using (true);

-- Members can maintain only their own profile, skills and availability.
create policy "members can insert own profile"
on public.profiles for insert
to authenticated
with check (id = auth.uid());

create policy "members can update own profile"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "members can insert own skills"
on public.skills for insert
to authenticated
with check (member_id = auth.uid());

create policy "members can update own skills"
on public.skills for update
to authenticated
using (member_id = auth.uid())
with check (member_id = auth.uid());

create policy "members can delete own skills"
on public.skills for delete
to authenticated
using (member_id = auth.uid());

create policy "members can insert own availability"
on public.availability for insert
to authenticated
with check (member_id = auth.uid());

create policy "members can update own availability"
on public.availability for update
to authenticated
using (member_id = auth.uid())
with check (member_id = auth.uid());

create policy "members can delete own availability"
on public.availability for delete
to authenticated
using (member_id = auth.uid());

create policy "members can respond to events"
on public.event_participants for insert
to authenticated
with check (member_id = auth.uid());

create policy "members can update own event response"
on public.event_participants for update
to authenticated
using (member_id = auth.uid())
with check (member_id = auth.uid());
