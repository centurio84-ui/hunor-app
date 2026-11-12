-- HUNOR App V1.4: iOS device tokens for push notifications

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null default 'ios' check (platform in ('ios')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(member_id, token)
);

alter table public.device_tokens enable row level security;

create policy "members can manage own device tokens"
on public.device_tokens for all
to authenticated
using (member_id = auth.uid())
with check (member_id = auth.uid());

create policy "admins can read device tokens"
on public.device_tokens for select
to authenticated
using (public.is_hunor_admin());

create index if not exists device_tokens_member_idx
on public.device_tokens(member_id);
