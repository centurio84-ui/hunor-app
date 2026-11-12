-- HUNOR App V1.1: role-based access control
-- Run after 001_initial_schema.sql.

create table if not exists public.member_roles (
  member_id uuid primary key references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('member','admin')),
  created_at timestamptz not null default now()
);

alter table public.member_roles enable row level security;

create or replace function public.is_hunor_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.member_roles
    where member_id = auth.uid()
      and role = 'admin'
  );
$$;

create policy "members can read own role"
on public.member_roles for select
to authenticated
using (member_id = auth.uid() or public.is_hunor_admin());

create policy "admins can manage roles"
on public.member_roles for all
to authenticated
using (public.is_hunor_admin())
with check (public.is_hunor_admin());

create policy "admins can manage events"
on public.events for all
to authenticated
using (public.is_hunor_admin())
with check (public.is_hunor_admin());

create policy "admins can manage profiles"
on public.profiles for update
to authenticated
using (id = auth.uid() or public.is_hunor_admin())
with check (id = auth.uid() or public.is_hunor_admin());

create policy "admins can manage skills"
on public.skills for all
to authenticated
using (member_id = auth.uid() or public.is_hunor_admin())
with check (member_id = auth.uid() or public.is_hunor_admin());

create policy "admins can manage availability"
on public.availability for all
to authenticated
using (member_id = auth.uid() or public.is_hunor_admin())
with check (member_id = auth.uid() or public.is_hunor_admin());

create policy "admins can manage event participants"
on public.event_participants for all
to authenticated
using (member_id = auth.uid() or public.is_hunor_admin())
with check (member_id = auth.uid() or public.is_hunor_admin());

-- The first admin can be assigned once a profile exists, for example:
-- insert into public.member_roles (member_id, role)
-- values ('AUTH-USER-UUID-HERE', 'admin')
-- on conflict (member_id) do update set role = excluded.role;
