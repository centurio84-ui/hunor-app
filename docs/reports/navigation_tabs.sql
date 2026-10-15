-- HUNOR single-organization portal. Menu flags do not replace business-data RLS.
create table public.navigation_tabs (
 id text primary key check(id ~ '^[a-z][a-z0-9_-]{1,59}$'),
 title text not null check(char_length(btrim(title)) between 1 and 100),
 route_path text not null unique check(route_path ~ '^/[a-z][a-z0-9_/-]*$'),
 icon_name text,
 is_visible boolean not null default false,
 sort_order integer not null default 0
);
alter table public.navigation_tabs enable row level security;
revoke all on public.navigation_tabs from anon,authenticated;
grant select,insert,update,delete on public.navigation_tabs to authenticated;

-- No user-editable JWT metadata. Approved membership and existing stored admin grants.
create function private.navigation_is_admin() returns boolean
language sql stable security definer set search_path=''
as $$ select auth.uid() is not null and private.lrc_admin(auth.uid()); $$;
revoke all on function private.navigation_is_admin() from public,anon;
grant execute on function private.navigation_is_admin() to authenticated;

create policy navigation_read on public.navigation_tabs for select to authenticated
 using ((select auth.uid()) is not null);
create policy navigation_insert on public.navigation_tabs for insert to authenticated
 with check ((select private.navigation_is_admin()));
create policy navigation_update on public.navigation_tabs for update to authenticated
 using ((select private.navigation_is_admin())) with check ((select private.navigation_is_admin()));
create policy navigation_delete on public.navigation_tabs for delete to authenticated
 using ((select private.navigation_is_admin()));

create function public.navigation_access_context() returns jsonb
language sql stable security invoker set search_path=''
as $$ select jsonb_build_object('is_admin',private.navigation_is_admin(),'is_approved_member',private.is_approved_hunor_member()); $$;
revoke all on function public.navigation_access_context() from public,anon;
grant execute on function public.navigation_access_context() to authenticated;

insert into public.navigation_tabs(id,title,route_path,icon_name,is_visible,sort_order) values
 ('home','Áttekintés','/home','home',true,10),
 ('excon','EXCON','/excon','account_tree',true,20),
 ('calendar','Naptár','/calendar','calendar_month',true,30),
 ('events','Események','/events','event',true,40),
 ('alerts','Riasztások','/alerts','notifications_active',true,45),
 ('education','Oktatás','/educationmenu','school',true,50),
 ('documents','Oktatási anyagok','/education','folder',true,51),
 ('elearning','E-learning','/elearning','school',true,52),
 ('paramedic','Paramedic','/paramedic','medical_services',true,53),
 ('forum','Csapat chat','/forum','chat',true,60),
 ('logistics','Logisztika','/logistics','inventory_2',true,70),
 ('members','Csapattagok','/members','groups',true,80),
 ('staffing','Állománytábla','/staffing','account_tree',true,90),
 ('rescue','Rescue Coins','/rescue','monetization_on',true,100),
 ('quizadmin','Lakossági kvíz','/quizadmin','quiz',true,110),
 ('profile','Profilom','/profile','person',true,120),
 ('approvals','Jóváhagyások','/approvals','verified_user',true,130),
 ('admin','Admin','/admin','admin_panel_settings',true,140);

-- All rows must be streamed: filtering is_visible on the subscription can miss true -> false.
alter publication supabase_realtime add table public.navigation_tabs;
