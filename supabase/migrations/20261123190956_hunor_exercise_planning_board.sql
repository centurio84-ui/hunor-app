begin;

-- Retain the original title for existing readers and catalog imports.
alter table public.insarag_checkpoint_catalog
  alter column title drop not null,
  add column code text unique check (btrim(code) <> ''),
  add column title_hu text check (btrim(title_hu) <> ''),
  add column title_en text,
  add column category text check (
    category in ('ASR', 'SEARCH', 'RESCUE', 'COORDINATION')
  ),
  add column default_duration_hours numeric check (
    default_duration_hours >= 0 and default_duration_hours < 'Infinity'::numeric
  ),
  add constraint insarag_checkpoint_display_title
    check (title_hu is not null or title is not null);

update public.insarag_checkpoint_catalog
set title_hu = title
where title_hu is null;

-- The link determines the type for existing rows and all future inserts.
alter table public.exercise_bubbles
  add column bubble_type text generated always as (
    case when checkpoint_id is null then 'custom' else 'checkpoint' end
  ) stored;

commit;
