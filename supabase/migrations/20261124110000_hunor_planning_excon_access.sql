begin;

-- 1. Gyakorlathoz rendelt EXCON tervezok tablaja (Admin kezeli)
create table if not exists public.exercise_planners (
  exercise_id uuid not null references public.exercises(id) on delete cascade,
  member_id uuid not null,
  assigned_by uuid,
  created_at timestamptz not null default now(),
  primary key (exercise_id, member_id)
);

create index if not exists exercise_planners_member_idx
  on public.exercise_planners (member_id, exercise_id);

alter table public.exercise_planners enable row level security;

revoke all on public.exercise_planners from public, anon, authenticated;
grant select, insert (exercise_id, member_id, assigned_by), delete
  on public.exercise_planners to authenticated;

-- 2. Jogosultsagi segedfuggvenyek
create or replace function private.is_hunor_planning_admin()
returns boolean
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null
     or pg_catalog.to_regclass('public.member_roles') is null then
    return false;
  end if;

  return exists (
    select 1
    from public.member_roles as mr
    where mr.member_id = (select auth.uid())
      and mr.role = 'admin'
  );
end;
$$;

create or replace function private.is_hunor_approved_excon()
returns boolean
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return false;
  end if;

  if pg_catalog.to_regclass('public.member_roles') is not null then
    if exists (
      select 1
      from public.member_roles as mr
      where mr.member_id = (select auth.uid())
        and (
          mr.role = 'admin'
          or to_jsonb(mr) ->> 'can_access_excon' = 'true'
        )
    ) then
      return true;
    end if;
  end if;

  -- Esemenyeknel sajat maga EXCON-nak jelentkezett es Admin jovahagyta
  if pg_catalog.to_regclass('public.event_participants') is not null then
    if exists (
      select 1
      from public.event_participants as ep
      where ep.member_id = (select auth.uid())
        and to_jsonb(ep) ->> 'participation_role' = 'excon'
        and coalesce(to_jsonb(ep) ->> 'status', 'approved') in ('approved', 'confirmed')
    ) then
      return true;
    end if;
  end if;

  return false;
end;
$$;

create or replace function private.can_access_hunor_exercise(p_exercise_id uuid)
returns boolean
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return false;
  end if;

  if private.is_hunor_planning_admin() or private.is_hunor_approved_excon() then
    return true;
  end if;

  return exists (
    select 1
    from public.exercise_planners as ep
    where ep.exercise_id = p_exercise_id
      and ep.member_id = (select auth.uid())
  );
end;
$$;

create or replace function private.can_manage_hunor_exercise_planning()
returns boolean
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return false;
  end if;

  if private.is_hunor_planning_admin() or private.is_hunor_approved_excon() then
    return true;
  end if;

  return exists (
    select 1
    from public.exercise_planners as ep
    where ep.member_id = (select auth.uid())
  );
end;
$$;

revoke all on function private.is_hunor_planning_admin() from public, anon, authenticated;
grant execute on function private.is_hunor_planning_admin() to authenticated;

revoke all on function private.is_hunor_approved_excon() from public, anon, authenticated;
grant execute on function private.is_hunor_approved_excon() to authenticated;

revoke all on function private.can_access_hunor_exercise(uuid) from public, anon, authenticated;
grant execute on function private.can_access_hunor_exercise(uuid) to authenticated;

revoke all on function private.can_manage_hunor_exercise_planning() from public, anon, authenticated;
grant execute on function private.can_manage_hunor_exercise_planning() to authenticated;

-- 3. RLS szabalyok: exercise_planners es exercises
drop policy if exists planning_planners_read on public.exercise_planners;
create policy planning_planners_read on public.exercise_planners
  for select to authenticated
  using (
    member_id = (select auth.uid())
    or (select private.is_hunor_planning_admin())
  );

drop policy if exists planning_planners_admin_write on public.exercise_planners;
create policy planning_planners_admin_write on public.exercise_planners
  for all to authenticated
  using ((select private.is_hunor_planning_admin()))
  with check ((select private.is_hunor_planning_admin()));

drop policy if exists planning_exercises_read on public.exercises;
create policy planning_exercises_read on public.exercises
  for select to authenticated
  using (
    organization_id = 'org-hunor'
    and (select private.can_access_hunor_exercise(id))
  );

drop policy if exists planning_exercises_create on public.exercises;
create policy planning_exercises_create on public.exercises
  for insert to authenticated
  with check (
    organization_id = 'org-hunor'
    and (select private.is_hunor_planning_admin() or private.is_hunor_approved_excon())
  );

commit;
