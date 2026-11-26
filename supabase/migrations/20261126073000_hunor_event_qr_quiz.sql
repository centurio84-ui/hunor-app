begin;

-- ============================================================================
-- EVENT-BASED QR QUIZ TABLES, CONSTRAINTS, RLS & SECURE RPCs
-- ============================================================================

create schema if not exists private;

create table if not exists public.quiz_events (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9_-]{1,62}$'),
  title text not null check (btrim(title) <> ''),
  is_active boolean not null default true,
  question_count integer not null default 10 check (question_count between 1 and 50),
  min_score integer not null default 7 check (min_score >= 0 and min_score <= question_count),
  staff_pin text not null default '1234' check (btrim(staff_pin) <> ''),
  created_at timestamptz not null default now()
);

create table if not exists public.quiz_event_submissions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.quiz_events(id) on delete cascade,
  device_hash text not null check (char_length(btrim(device_hash)) between 8 and 128),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  score integer check (score is null or score >= 0),
  reward_code text unique,
  is_redeemed boolean not null default false,
  constraint quiz_event_submissions_event_device_key unique (event_id, device_hash)
);

create index if not exists quiz_events_slug_idx on public.quiz_events (slug);
create index if not exists quiz_event_submissions_event_idx on public.quiz_event_submissions (event_id, started_at desc);

alter table public.quiz_events enable row level security;
alter table public.quiz_event_submissions enable row level security;

revoke all on public.quiz_events from public, anon, authenticated;
revoke all on public.quiz_event_submissions from public, anon, authenticated;

-- Admins check helper (reuses member_roles.role = 'admin')
create or replace function private.is_hunor_quiz_event_admin()
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or pg_catalog.to_regclass('public.member_roles') is null then
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

revoke all on function private.is_hunor_quiz_event_admin() from public, anon, authenticated;
grant execute on function private.is_hunor_quiz_event_admin() to authenticated;

-- Admin full table access for Organizer Event Manager UI
grant select, insert, update, delete on public.quiz_events to authenticated;
grant select, update, delete on public.quiz_event_submissions to authenticated;

drop policy if exists quiz_events_admin_all on public.quiz_events;
create policy quiz_events_admin_all on public.quiz_events
  for all to authenticated
  using ((select private.is_hunor_quiz_event_admin()))
  with check ((select private.is_hunor_quiz_event_admin()));

drop policy if exists quiz_event_submissions_admin_all on public.quiz_event_submissions;
create policy quiz_event_submissions_admin_all on public.quiz_event_submissions
  for all to authenticated
  using ((select private.is_hunor_quiz_event_admin()))
  with check ((select private.is_hunor_quiz_event_admin()));

-- ============================================================================
-- PUBLIC / GUEST SECURITY DEFINER RPCs (staff_pin NEVER exposed to guests!)
-- ============================================================================

-- 1. Load public event info + existing submission for (slug, device_hash)
create or replace function public.get_public_quiz_event_state(
  p_slug text,
  p_device_hash text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_event public.quiz_events%rowtype;
  v_sub public.quiz_event_submissions%rowtype;
begin
  select * into v_event
  from public.quiz_events
  where lower(slug) = lower(btrim(coalesce(p_slug, '')))
  limit 1;

  if not found then
    return jsonb_build_object('found', false);
  end if;

  select * into v_sub
  from public.quiz_event_submissions
  where event_id = v_event.id
    and device_hash = btrim(coalesce(p_device_hash, ''))
  limit 1;

  return jsonb_build_object(
    'found', true,
    'event', jsonb_build_object(
      'id', v_event.id,
      'slug', v_event.slug,
      'title', v_event.title,
      'is_active', v_event.is_active,
      'question_count', v_event.question_count,
      'min_score', v_event.min_score,
      'created_at', v_event.created_at
    ),
    'submission', case when v_sub.id is null then null else jsonb_build_object(
      'id', v_sub.id,
      'event_id', v_sub.event_id,
      'started_at', v_sub.started_at,
      'completed_at', v_sub.completed_at,
      'score', v_sub.score,
      'reward_code', v_sub.reward_code,
      'is_redeemed', v_sub.is_redeemed
    ) end
  );
end;
$$;

-- 2. Start quiz attempt: inserts started_at (idempotent if started but not completed; rejects if completed)
create or replace function public.start_quiz_event_submission(
  p_event_id uuid,
  p_device_hash text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_event public.quiz_events%rowtype;
  v_sub public.quiz_event_submissions%rowtype;
  v_hash text := btrim(coalesce(p_device_hash, ''));
begin
  if char_length(v_hash) < 8 or char_length(v_hash) > 128 then
    raise exception 'INVALID_DEVICE_HASH';
  end if;

  select * into v_event
  from public.quiz_events
  where id = p_event_id;

  if not found or not v_event.is_active then
    raise exception 'EVENT_INACTIVE_OR_NOT_FOUND';
  end if;

  insert into public.quiz_event_submissions (event_id, device_hash, started_at)
  values (p_event_id, v_hash, now())
  on conflict (event_id, device_hash) do nothing;

  select * into v_sub
  from public.quiz_event_submissions
  where event_id = p_event_id and device_hash = v_hash;

  return jsonb_build_object(
    'id', v_sub.id,
    'event_id', v_sub.event_id,
    'started_at', v_sub.started_at,
    'completed_at', v_sub.completed_at,
    'score', v_sub.score,
    'reward_code', v_sub.reward_code,
    'is_redeemed', v_sub.is_redeemed
  );
end;
$$;

-- 3. Complete quiz attempt: sets completed_at, score, and generates unique 6-char alphanumeric reward_code if score >= min_score
create or replace function public.complete_quiz_event_submission(
  p_event_id uuid,
  p_device_hash text,
  p_score integer
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_event public.quiz_events%rowtype;
  v_sub public.quiz_event_submissions%rowtype;
  v_hash text := btrim(coalesce(p_device_hash, ''));
  v_chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  v_attempt int := 0;
begin
  select * into v_event
  from public.quiz_events
  where id = p_event_id;

  if not found then
    raise exception 'EVENT_NOT_FOUND';
  end if;

  if p_score < 0 or p_score > v_event.question_count then
    raise exception 'INVALID_SCORE';
  end if;

  -- Ensure a started row exists even if offline/reconnected
  insert into public.quiz_event_submissions (event_id, device_hash, started_at)
  values (p_event_id, v_hash, now())
  on conflict (event_id, device_hash) do nothing;

  select * into v_sub
  from public.quiz_event_submissions
  where event_id = p_event_id and device_hash = v_hash
  for update;

  -- One completion per device: if already completed, return the saved result untouched!
  if v_sub.completed_at is not null then
    return jsonb_build_object(
      'id', v_sub.id,
      'event_id', v_sub.event_id,
      'started_at', v_sub.started_at,
      'completed_at', v_sub.completed_at,
      'score', v_sub.score,
      'reward_code', v_sub.reward_code,
      'is_redeemed', v_sub.is_redeemed,
      'already_completed', true
    );
  end if;

  v_code := null;
  if p_score >= v_event.min_score then
    loop
      v_attempt := v_attempt + 1;
      v_code := '';
      for i in 1..6 loop
        v_code := v_code || substr(v_chars, floor(random() * length(v_chars))::int + 1, 1);
      end loop;
      exit when not exists (
        select 1 from public.quiz_event_submissions where reward_code = v_code
      ) or v_attempt > 25;
    end loop;
  end if;

  update public.quiz_event_submissions
  set completed_at = now(),
      score = p_score,
      reward_code = v_code
  where id = v_sub.id
  returning * into v_sub;

  return jsonb_build_object(
    'id', v_sub.id,
    'event_id', v_sub.event_id,
    'started_at', v_sub.started_at,
    'completed_at', v_sub.completed_at,
    'score', v_sub.score,
    'reward_code', v_sub.reward_code,
    'is_redeemed', v_sub.is_redeemed,
    'already_completed', false
  );
end;
$$;

-- 4. Redeem Prize (Staff Only): validates staff_pin server-side and sets is_redeemed = true
create or replace function public.redeem_quiz_event_prize(
  p_submission_id uuid,
  p_device_hash text,
  p_staff_pin text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_sub public.quiz_event_submissions%rowtype;
  v_event public.quiz_events%rowtype;
begin
  select * into v_sub
  from public.quiz_event_submissions
  where id = p_submission_id
    and device_hash = btrim(coalesce(p_device_hash, ''))
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'SUBMISSION_NOT_FOUND');
  end if;

  if v_sub.reward_code is null then
    return jsonb_build_object('ok', false, 'error', 'NO_REWARD_EARNED');
  end if;

  select * into v_event
  from public.quiz_events
  where id = v_sub.event_id;

  if btrim(coalesce(p_staff_pin, '')) <> v_event.staff_pin then
    return jsonb_build_object('ok', false, 'error', 'INVALID_STAFF_PIN');
  end if;

  update public.quiz_event_submissions
  set is_redeemed = true
  where id = v_sub.id
  returning * into v_sub;

  return jsonb_build_object(
    'ok', true,
    'is_redeemed', v_sub.is_redeemed,
    'reward_code', v_sub.reward_code
  );
end;
$$;

-- 5. Admin Live Metrics Summary RPC (fast single-call dashboard aggregation)
create or replace function public.get_quiz_events_with_metrics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_hunor_quiz_event_admin() then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(row_data order by created_at desc)
    from (
      select
        e.created_at,
        jsonb_build_object(
          'id', e.id,
          'slug', e.slug,
          'title', e.title,
          'is_active', e.is_active,
          'question_count', e.question_count,
          'min_score', e.min_score,
          'staff_pin', e.staff_pin,
          'created_at', e.created_at,
          'started_count', count(s.id),
          'completed_count', count(s.id) filter (where s.completed_at is not null),
          'qualified_count', count(s.id) filter (where s.reward_code is not null),
          'redeemed_count', count(s.id) filter (where s.is_redeemed = true)
        ) as row_data
      from public.quiz_events e
      left join public.quiz_event_submissions s on s.event_id = e.id
      group by e.id
    ) sub
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.get_public_quiz_event_state(text, text) from public;
grant execute on function public.get_public_quiz_event_state(text, text) to anon, authenticated;

revoke all on function public.start_quiz_event_submission(uuid, text) from public;
grant execute on function public.start_quiz_event_submission(uuid, text) to anon, authenticated;

revoke all on function public.complete_quiz_event_submission(uuid, text, integer) from public;
grant execute on function public.complete_quiz_event_submission(uuid, text, integer) to anon, authenticated;

revoke all on function public.redeem_quiz_event_prize(uuid, text, text) from public;
grant execute on function public.redeem_quiz_event_prize(uuid, text, text) to anon, authenticated;

revoke all on function public.get_quiz_events_with_metrics() from public, anon;
grant execute on function public.get_quiz_events_with_metrics() to authenticated;

notify pgrst, 'reload schema';

commit;
