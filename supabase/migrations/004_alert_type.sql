-- HUNOR App V1.3: replace alert priority with operational alert type

alter table public.alerts
  rename column priority to type;

alter table public.alerts
  drop constraint if exists alerts_priority_check;

alter table public.alerts
  add constraint alerts_type_check
  check (type in ('exercise', 'standby', 'alert'));

update public.alerts
set type = case type
  when 'normal' then 'alert'
  when 'high' then 'standby'
  when 'critical' then 'alert'
  else 'alert'
end
where type not in ('exercise', 'standby', 'alert');
