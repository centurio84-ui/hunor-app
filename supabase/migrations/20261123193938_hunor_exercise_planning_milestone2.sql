begin;

-- Keep the existing checkpoint/custom values and allow explicit disciplines.
alter table public.exercise_bubbles
  alter column bubble_type drop expression,
  alter column bubble_type set not null,
  add constraint exercise_bubbles_type_matches_checkpoint check (
    (bubble_type = 'checkpoint' and checkpoint_id is not null)
    or (bubble_type in ('custom', 'medical', 'ucc', 'press_vip')
        and checkpoint_id is null)
  ),
  add constraint exercise_bubbles_exercise_id_id_key unique (exercise_id, id);

create function private.default_planning_bubble_type()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.bubble_type is null then
    new.bubble_type := case when new.checkpoint_id is null
      then 'custom' else 'checkpoint' end;
  end if;
  return new;
end;
$$;

revoke all on function private.default_planning_bubble_type()
  from public, anon, authenticated;

create trigger default_planning_bubble_type
before insert on public.exercise_bubbles
for each row execute function private.default_planning_bubble_type();

grant insert (bubble_type), update (bubble_type)
  on public.exercise_bubbles to authenticated;

create table public.exercise_timeline_blocks (
  id uuid primary key default gen_random_uuid(),
  exercise_id uuid not null references public.exercises(id) on delete cascade,
  sector_id uuid,
  bubble_id uuid not null,
  planned_start_hour numeric not null
    check (planned_start_hour >= 0 and planned_start_hour < 'Infinity'::numeric),
  planned_duration_hours numeric not null
    check (planned_duration_hours > 0 and planned_duration_hours < 'Infinity'::numeric),
  actual_start_hour numeric
    check (actual_start_hour >= 0 and actual_start_hour < 'Infinity'::numeric),
  actual_duration_hours numeric
    check (actual_duration_hours > 0 and actual_duration_hours < 'Infinity'::numeric),
  is_copied_to_actual boolean not null default false,
  status text not null default 'planned'
    check (status in ('planned', 'in_progress', 'delayed', 'completed')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (is_copied_to_actual and actual_start_hour is not null and actual_duration_hours is not null)
    or (not is_copied_to_actual and actual_start_hour is null and actual_duration_hours is null and status = 'planned')
  ),
  unique (exercise_id, bubble_id),
  foreign key (exercise_id, bubble_id)
    references public.exercise_bubbles(exercise_id, id) on delete cascade,
  foreign key (exercise_id, sector_id)
    references public.exercise_sectors(exercise_id, id) on delete set null (sector_id)
);

create index exercise_timeline_blocks_exercise_start_idx
  on public.exercise_timeline_blocks (exercise_id, planned_start_hour, id);
create index exercise_timeline_blocks_exercise_sector_idx
  on public.exercise_timeline_blocks (exercise_id, sector_id)
  where sector_id is not null;

create function private.touch_exercise_timeline_block()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := pg_catalog.clock_timestamp();
  return new;
end;
$$;

revoke all on function private.touch_exercise_timeline_block()
  from public, anon, authenticated;

create trigger touch_exercise_timeline_block
before update on public.exercise_timeline_blocks
for each row execute function private.touch_exercise_timeline_block();

alter table public.exercise_timeline_blocks enable row level security;
revoke all on public.exercise_timeline_blocks from public, anon, authenticated;
grant select, delete,
  insert (exercise_id, sector_id, bubble_id, planned_start_hour, planned_duration_hours, notes),
  update (sector_id, planned_start_hour, planned_duration_hours, actual_start_hour,
    actual_duration_hours, is_copied_to_actual, status, notes)
  on public.exercise_timeline_blocks to authenticated;

create policy planning_timeline_blocks_access on public.exercise_timeline_blocks
  for all to authenticated
  using (exists (
    select 1 from public.exercises as exercise
    where exercise.id = exercise_timeline_blocks.exercise_id
  ))
  with check (exists (
    select 1 from public.exercises as exercise
    where exercise.id = exercise_timeline_blocks.exercise_id
  ));

-- Copy the current database values atomically, returning the updated block.
-- First-time copies cannot overwrite a Real track created by another controller.
create function public.copy_planning_block_to_actual(
  p_exercise_id uuid, p_block_id uuid, p_overwrite boolean
)
returns setof public.exercise_timeline_blocks
language sql
volatile
security invoker
set search_path = ''
as $$
  update public.exercise_timeline_blocks
  set actual_start_hour = planned_start_hour,
      actual_duration_hours = planned_duration_hours,
      is_copied_to_actual = true
  where exercise_id = p_exercise_id and id = p_block_id
    and (not is_copied_to_actual or p_overwrite)
  returning *;
$$;

revoke all on function public.copy_planning_block_to_actual(uuid, uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.copy_planning_block_to_actual(uuid, uuid, boolean)
  to authenticated;

commit;
