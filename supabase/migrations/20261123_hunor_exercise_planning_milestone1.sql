begin;

create schema if not exists private;

-- The production Flutter Supabase adapter currently serves one organization.
-- Event EXCON registrations can be self-selected, so the database requires a
-- role grant. Projects without the HUNOR role table deny access by default.
create function private.can_manage_hunor_exercise_planning()
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
    from public.member_roles as member_role
    where member_role.member_id = (select auth.uid())
      and (
        member_role.role = 'admin'
        or to_jsonb(member_role) ->> 'can_access_excon' = 'true'
      )
  );
end;
$$;

revoke all on function private.can_manage_hunor_exercise_planning()
  from public, anon, authenticated;
grant execute on function private.can_manage_hunor_exercise_planning()
  to authenticated;

create table public.insarag_checkpoint_catalog (
  id uuid primary key default gen_random_uuid(),
  title text not null check (btrim(title) <> ''),
  sort_order integer not null
);

create table public.exercises (
  id uuid primary key default gen_random_uuid(),
  organization_id text not null check (organization_id = 'org-hunor'),
  title text not null check (btrim(title) <> ''),
  created_at timestamptz not null default now()
);

create table public.exercise_sectors (
  id uuid primary key default gen_random_uuid(),
  exercise_id uuid not null references public.exercises(id) on delete cascade,
  number integer not null check (number > 0),
  name text generated always as ('ROM ' || number::text) stored,
  unique (exercise_id, number),
  unique (exercise_id, id)
);

create table public.exercise_bubbles (
  id uuid primary key default gen_random_uuid(),
  exercise_id uuid not null references public.exercises(id) on delete cascade,
  sector_id uuid,
  checkpoint_id uuid references public.insarag_checkpoint_catalog(id),
  estimated_hours numeric check (
    estimated_hours >= 0 and estimated_hours < 'Infinity'::numeric
  ),
  title text not null check (btrim(title) <> ''),
  specs jsonb not null default '{}'::jsonb
    check (jsonb_typeof(specs) = 'object'),
  created_at timestamptz not null default now(),
  foreign key (exercise_id, sector_id)
    references public.exercise_sectors(exercise_id, id)
    on delete set null (sector_id)
);

create index insarag_checkpoint_catalog_sort_order_idx
  on public.insarag_checkpoint_catalog (sort_order, id);
create index exercises_org_created_idx
  on public.exercises (organization_id, created_at desc, id);
create index exercise_bubbles_exercise_created_idx
  on public.exercise_bubbles (exercise_id, created_at, id);
create index exercise_bubbles_exercise_sector_idx
  on public.exercise_bubbles (exercise_id, sector_id)
  where sector_id is not null;

alter table public.insarag_checkpoint_catalog enable row level security;
alter table public.exercises enable row level security;
alter table public.exercise_sectors enable row level security;
alter table public.exercise_bubbles enable row level security;

revoke all on public.insarag_checkpoint_catalog, public.exercises,
  public.exercise_sectors, public.exercise_bubbles
  from public, anon, authenticated;

grant select on public.insarag_checkpoint_catalog to authenticated;
grant select, insert (organization_id, title) on public.exercises to authenticated;
grant select, insert (exercise_id, number) on public.exercise_sectors to authenticated;
grant select, delete,
  insert (exercise_id, sector_id, checkpoint_id, estimated_hours, title, specs),
  update (sector_id, estimated_hours, title, specs)
  on public.exercise_bubbles to authenticated;

create policy planning_catalog_read on public.insarag_checkpoint_catalog
  for select to authenticated
  using ((select private.can_manage_hunor_exercise_planning()));

create policy planning_exercises_read on public.exercises
  for select to authenticated
  using (
    organization_id = 'org-hunor'
    and (select private.can_manage_hunor_exercise_planning())
  );

create policy planning_exercises_create on public.exercises
  for insert to authenticated
  with check (
    organization_id = 'org-hunor'
    and (select private.can_manage_hunor_exercise_planning())
  );

-- Parent visibility applies the organization and role checks to every child.
create policy planning_sectors_access on public.exercise_sectors
  for all to authenticated
  using (exists (
    select 1 from public.exercises as exercise
    where exercise.id = exercise_sectors.exercise_id
  ))
  with check (exists (
    select 1 from public.exercises as exercise
    where exercise.id = exercise_sectors.exercise_id
  ));

create policy planning_bubbles_access on public.exercise_bubbles
  for all to authenticated
  using (exists (
    select 1 from public.exercises as exercise
    where exercise.id = exercise_bubbles.exercise_id
  ))
  with check (exists (
    select 1 from public.exercises as exercise
    where exercise.id = exercise_bubbles.exercise_id
  ));

create function private.add_default_exercise_sectors()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  insert into public.exercise_sectors (exercise_id, number)
  values (new.id, 1), (new.id, 2), (new.id, 3);
  return new;
end;
$$;

revoke all on function private.add_default_exercise_sectors()
  from public, anon, authenticated;

create trigger add_default_exercise_sectors
after insert on public.exercises
for each row execute function private.add_default_exercise_sectors();

create function public.create_planning_sector(p_exercise_id uuid)
returns setof public.exercise_sectors
language plpgsql
volatile
security invoker
set search_path = ''
as $$
begin
  if not exists (select 1 from public.exercises where id = p_exercise_id) then
    raise exception 'Exercise not found' using errcode = 'P0002';
  end if;

  -- Serialize number allocation for requests targeting the same exercise.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_exercise_id::text, 0)
  );

  return query
    insert into public.exercise_sectors (exercise_id, number)
    select p_exercise_id, coalesce(max(number), 0) + 1
    from public.exercise_sectors
    where exercise_id = p_exercise_id
    returning *;
end;
$$;

revoke all on function public.create_planning_sector(uuid)
  from public, anon, authenticated;
grant execute on function public.create_planning_sector(uuid) to authenticated;

commit;
