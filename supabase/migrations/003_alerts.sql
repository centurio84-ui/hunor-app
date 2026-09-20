-- HUNOR App V1.2: operational alerts
-- Run after 002_roles_and_admin.sql.

create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  message text not null,
  priority text not null default 'normal' check (priority in ('normal','high','critical')),
  status text not null default 'active' check (status in ('active','closed')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz
);

create table if not exists public.alert_responses (
  alert_id uuid not null references public.alerts(id) on delete cascade,
  member_id uuid not null references public.profiles(id) on delete cascade,
  response text not null check (response in ('available','unavailable')),
  responded_at timestamptz not null default now(),
  primary key (alert_id, member_id)
);

alter table public.alerts enable row level security;
alter table public.alert_responses enable row level security;

create policy "members can read alerts"
on public.alerts for select
to authenticated
using (true);

create policy "admins can manage alerts"
on public.alerts for all
to authenticated
using (public.is_hunor_admin())
with check (public.is_hunor_admin());

create policy "members can read alert responses"
on public.alert_responses for select
to authenticated
using (true);

create policy "members can respond to alerts"
on public.alert_responses for insert
to authenticated
with check (member_id = auth.uid());

create policy "members can update own alert response"
on public.alert_responses for update
to authenticated
using (member_id = auth.uid())
with check (member_id = auth.uid());

create policy "admins can manage alert responses"
on public.alert_responses for all
to authenticated
using (public.is_hunor_admin())
with check (public.is_hunor_admin());

create index if not exists alerts_status_created_at_idx
on public.alerts(status, created_at desc);
