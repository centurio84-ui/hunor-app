begin;

-- 3D Konténerváz tervező jelenet (konténerek, ablakok, akadályok, sérült-elhelyezések)
-- szinkronizálása az exercises táblába JSONB oszlopként.
alter table public.exercises
  add column if not exists scene_3d jsonb not null default '{}'::jsonb
    check (jsonb_typeof(scene_3d) = 'object');

grant update (scene_3d) on public.exercises to authenticated;

drop policy if exists planning_exercises_update on public.exercises;
create policy planning_exercises_update on public.exercises
  for update to authenticated
  using (
    organization_id = 'org-hunor'
    and (select private.can_access_hunor_exercise(id))
  )
  with check (
    organization_id = 'org-hunor'
    and (select private.can_access_hunor_exercise(id))
  );

commit;
