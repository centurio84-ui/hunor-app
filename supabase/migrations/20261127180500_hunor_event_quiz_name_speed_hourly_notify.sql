-- ============================================================================
-- EVENT QUIZ: PARTICIPANT NAME, DURATION TRACKING & HOURLY ADMIN NOTIFICATIONS
-- ============================================================================
BEGIN;

-- 1. Event-level toggles for requiring participant name & hourly leader alerts
ALTER TABLE public.quiz_events
  ADD COLUMN IF NOT EXISTS require_participant_name boolean NOT NULL DEFAULT true;

ALTER TABLE public.quiz_events
  ADD COLUMN IF NOT EXISTS hourly_leader_notify boolean NOT NULL DEFAULT true;

-- 2. Submission-level participant_name & exact completion time (duration_ms)
ALTER TABLE public.quiz_event_submissions
  ADD COLUMN IF NOT EXISTS participant_name text;

ALTER TABLE public.quiz_event_submissions
  ADD COLUMN IF NOT EXISTS duration_ms integer;

-- Backfill duration_ms for already completed submissions from (completed_at - started_at)
UPDATE public.quiz_event_submissions
SET duration_ms = GREATEST(1000, LEAST(3600000, ROUND(EXTRACT(EPOCH FROM (completed_at - started_at)) * 1000)::int))
WHERE completed_at IS NOT NULL
  AND started_at IS NOT NULL
  AND duration_ms IS NULL;

CREATE INDEX IF NOT EXISTS idx_quiz_event_submissions_leader
  ON public.quiz_event_submissions(event_id, score DESC, duration_ms ASC)
  WHERE completed_at IS NOT NULL;

-- 3. Hourly leader notifications table (deduplicated per event_id + hour_bucket)
CREATE TABLE IF NOT EXISTS public.quiz_event_hourly_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.quiz_events(id) ON DELETE CASCADE,
  hour_bucket timestamptz NOT NULL,
  hourly_winner_name text,
  hourly_winner_score int,
  hourly_winner_duration_ms int,
  hourly_completions_count int NOT NULL DEFAULT 0,
  overall_winner_name text,
  overall_winner_score int,
  overall_winner_duration_ms int,
  overall_completions_count int NOT NULL DEFAULT 0,
  summary_text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(event_id, hour_bucket)
);

ALTER TABLE public.quiz_event_hourly_notifications ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT ON public.quiz_event_hourly_notifications TO authenticated;

DROP POLICY IF EXISTS "Authenticated read quiz hourly notifications" ON public.quiz_event_hourly_notifications;
CREATE POLICY "Authenticated read quiz hourly notifications"
  ON public.quiz_event_hourly_notifications
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated insert quiz hourly notifications" ON public.quiz_event_hourly_notifications;
CREATE POLICY "Authenticated insert quiz hourly notifications"
  ON public.quiz_event_hourly_notifications
  FOR INSERT TO authenticated WITH CHECK (true);

-- 4. Update public RPCs to include require_participant_name, participant_name, and duration_ms
CREATE OR REPLACE FUNCTION public.get_public_quiz_event_state(
  p_slug text,
  p_device_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_event public.quiz_events%rowtype;
  v_sub public.quiz_event_submissions%rowtype;
BEGIN
  SELECT * INTO v_event
  FROM public.quiz_events
  WHERE lower(slug) = lower(btrim(coalesce(p_slug, '')))
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  SELECT * INTO v_sub
  FROM public.quiz_event_submissions
  WHERE event_id = v_event.id
    AND device_hash = btrim(coalesce(p_device_hash, ''))
  LIMIT 1;

  RETURN jsonb_build_object(
    'found', true,
    'event', jsonb_build_object(
      'id', v_event.id,
      'slug', v_event.slug,
      'title', v_event.title,
      'selected_categories', v_event.selected_categories,
      'is_active', v_event.is_active,
      'question_count', v_event.question_count,
      'min_score', v_event.min_score,
      'reward_enabled', v_event.reward_enabled,
      'reward_name', v_event.reward_name,
      'require_participant_name', v_event.require_participant_name,
      'hourly_leader_notify', v_event.hourly_leader_notify,
      'created_at', v_event.created_at
    ),
    'submission', CASE WHEN v_sub.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id', v_sub.id,
      'event_id', v_sub.event_id,
      'participant_name', v_sub.participant_name,
      'started_at', v_sub.started_at,
      'completed_at', v_sub.completed_at,
      'duration_ms', v_sub.duration_ms,
      'score', v_sub.score,
      'reward_code', v_sub.reward_code,
      'is_redeemed', v_sub.is_redeemed
    ) END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.start_quiz_event_submission(
  p_event_id uuid,
  p_device_hash text,
  p_participant_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_event public.quiz_events%rowtype;
  v_sub public.quiz_event_submissions%rowtype;
  v_hash text := btrim(coalesce(p_device_hash, ''));
  v_name text := NULLIF(btrim(coalesce(p_participant_name, '')), '');
BEGIN
  IF char_length(v_hash) < 8 OR char_length(v_hash) > 128 THEN
    RAISE EXCEPTION 'INVALID_DEVICE_HASH';
  END IF;

  SELECT * INTO v_event
  FROM public.quiz_events
  WHERE id = p_event_id;

  IF NOT FOUND OR NOT v_event.is_active THEN
    RAISE EXCEPTION 'EVENT_INACTIVE_OR_NOT_FOUND';
  END IF;

  INSERT INTO public.quiz_event_submissions (event_id, device_hash, participant_name, started_at)
  VALUES (p_event_id, v_hash, v_name, now())
  ON CONFLICT (event_id, device_hash) DO UPDATE
    SET participant_name = COALESCE(EXCLUDED.participant_name, public.quiz_event_submissions.participant_name),
        started_at = CASE
          WHEN public.quiz_event_submissions.completed_at IS NULL THEN now()
          ELSE public.quiz_event_submissions.started_at
        END;

  SELECT * INTO v_sub
  FROM public.quiz_event_submissions
  WHERE event_id = p_event_id AND device_hash = v_hash;

  RETURN jsonb_build_object(
    'id', v_sub.id,
    'event_id', v_sub.event_id,
    'participant_name', v_sub.participant_name,
    'started_at', v_sub.started_at,
    'completed_at', v_sub.completed_at,
    'duration_ms', v_sub.duration_ms,
    'score', v_sub.score,
    'reward_code', v_sub.reward_code,
    'is_redeemed', v_sub.is_redeemed
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_quiz_event_submission(
  p_event_id uuid,
  p_device_hash text,
  p_score integer,
  p_participant_name text DEFAULT NULL,
  p_duration_ms integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_event public.quiz_events%rowtype;
  v_sub public.quiz_event_submissions%rowtype;
  v_hash text := btrim(coalesce(p_device_hash, ''));
  v_name text := NULLIF(btrim(coalesce(p_participant_name, '')), '');
  v_chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  v_attempt int := 0;
  v_calc_ms int;
BEGIN
  SELECT * INTO v_event
  FROM public.quiz_events
  WHERE id = p_event_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'EVENT_NOT_FOUND';
  END IF;

  IF p_score < 0 OR p_score > v_event.question_count THEN
    RAISE EXCEPTION 'INVALID_SCORE';
  END IF;

  INSERT INTO public.quiz_event_submissions (event_id, device_hash, participant_name, started_at)
  VALUES (p_event_id, v_hash, v_name, now())
  ON CONFLICT (event_id, device_hash) DO NOTHING;

  SELECT * INTO v_sub
  FROM public.quiz_event_submissions
  WHERE event_id = p_event_id AND device_hash = v_hash
  FOR UPDATE;

  IF v_sub.completed_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'id', v_sub.id,
      'event_id', v_sub.event_id,
      'participant_name', v_sub.participant_name,
      'started_at', v_sub.started_at,
      'completed_at', v_sub.completed_at,
      'duration_ms', v_sub.duration_ms,
      'score', v_sub.score,
      'reward_code', v_sub.reward_code,
      'is_redeemed', v_sub.is_redeemed,
      'already_completed', true
    );
  END IF;

  v_calc_ms := COALESCE(
    p_duration_ms,
    GREATEST(1000, LEAST(3600000, ROUND(EXTRACT(EPOCH FROM (now() - v_sub.started_at)) * 1000)::int))
  );

  v_code := NULL;
  IF v_event.reward_enabled
     AND btrim(coalesce(v_event.reward_name, '')) <> ''
     AND v_event.reward_name <> 'Ajándék nyeremény'
     AND p_score >= v_event.min_score THEN
    LOOP
      v_attempt := v_attempt + 1;
      v_code := 'KUPON-' || substr(v_chars, floor(random() * length(v_chars))::int + 1, 1)
                         || substr(v_chars, floor(random() * length(v_chars))::int + 1, 1)
                         || substr(v_chars, floor(random() * length(v_chars))::int + 1, 1)
                         || substr(v_chars, floor(random() * length(v_chars))::int + 1, 1);
      EXIT WHEN NOT EXISTS (
        SELECT 1 FROM public.quiz_event_submissions WHERE reward_code = v_code
      ) OR v_attempt > 25;
    END LOOP;
  END IF;

  UPDATE public.quiz_event_submissions
  SET completed_at = now(),
      participant_name = COALESCE(v_name, participant_name),
      duration_ms = v_calc_ms,
      score = p_score,
      reward_code = v_code
  WHERE id = v_sub.id
  RETURNING * INTO v_sub;

  RETURN jsonb_build_object(
    'id', v_sub.id,
    'event_id', v_sub.event_id,
    'participant_name', v_sub.participant_name,
    'started_at', v_sub.started_at,
    'completed_at', v_sub.completed_at,
    'duration_ms', v_sub.duration_ms,
    'score', v_sub.score,
    'reward_code', v_sub.reward_code,
    'is_redeemed', v_sub.is_redeemed,
    'already_completed', false
  );
END;
$$;

-- 5. Hourly Leader Digest Generator RPC (can be called by pg_cron AND/OR any active admin session)
CREATE OR REPLACE FUNCTION public.check_and_emit_quiz_hourly_leaders(
  p_force_current_hour boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_ev RECORD;
  v_bucket_start timestamptz;
  v_bucket_end timestamptz;
  v_hourly_leader RECORD;
  v_overall_leader RECORD;
  v_hourly_count int;
  v_overall_count int;
  v_summary text;
  v_emitted jsonb := '[]'::jsonb;
  v_inserted_row public.quiz_event_hourly_notifications%rowtype;
BEGIN
  IF p_force_current_hour THEN
    v_bucket_start := date_trunc('hour', now());
    v_bucket_end := now();
  ELSE
    -- Report the most recently completed clock hour (e.g. at 18:00..18:59 reports 17:00–18:00)
    v_bucket_end := date_trunc('hour', now());
    v_bucket_start := v_bucket_end - interval '1 hour';
  END IF;

  FOR v_ev IN
    SELECT * FROM public.quiz_events
    WHERE is_active = true AND hourly_leader_notify = true
  LOOP
    -- Skip if already emitted for this hour_bucket (unless p_force_current_hour)
    IF NOT p_force_current_hour AND EXISTS (
      SELECT 1 FROM public.quiz_event_hourly_notifications
      WHERE event_id = v_ev.id AND hour_bucket = v_bucket_start
    ) THEN
      CONTINUE;
    END IF;

    SELECT count(*) INTO v_overall_count
    FROM public.quiz_event_submissions
    WHERE event_id = v_ev.id AND completed_at IS NOT NULL;

    IF v_overall_count = 0 THEN
      CONTINUE;
    END IF;

    SELECT count(*) INTO v_hourly_count
    FROM public.quiz_event_submissions
    WHERE event_id = v_ev.id
      AND completed_at IS NOT NULL
      AND completed_at >= v_bucket_start
      AND completed_at < CASE WHEN p_force_current_hour THEN now() + interval '1 second' ELSE v_bucket_end END;

    -- Best & fastest in the hour window
    SELECT
      COALESCE(NULLIF(btrim(participant_name), ''), 'Névtelen kitöltő') AS p_name,
      score,
      COALESCE(duration_ms, GREATEST(1000, ROUND(EXTRACT(EPOCH FROM (completed_at - started_at)) * 1000)::int)) AS dur_ms
    INTO v_hourly_leader
    FROM public.quiz_event_submissions
    WHERE event_id = v_ev.id
      AND completed_at IS NOT NULL
      AND completed_at >= v_bucket_start
      AND completed_at < CASE WHEN p_force_current_hour THEN now() + interval '1 second' ELSE v_bucket_end END
    ORDER BY score DESC, dur_ms ASC, completed_at ASC
    LIMIT 1;

    -- Best & fastest overall for the event
    SELECT
      COALESCE(NULLIF(btrim(participant_name), ''), 'Névtelen kitöltő') AS p_name,
      score,
      COALESCE(duration_ms, GREATEST(1000, ROUND(EXTRACT(EPOCH FROM (completed_at - started_at)) * 1000)::int)) AS dur_ms
    INTO v_overall_leader
    FROM public.quiz_event_submissions
    WHERE event_id = v_ev.id
      AND completed_at IS NOT NULL
    ORDER BY score DESC, dur_ms ASC, completed_at ASC
    LIMIT 1;

    -- Only auto-emit at the top of the hour if there was at least 1 completion in the past hour (or if forced)
    IF v_hourly_count = 0 AND NOT p_force_current_hour THEN
      CONTINUE;
    END IF;

    v_summary := format(
      '🏆 [%s] Óránkénti kvíz-összesítő: Összesített 1. hely: %s (%s/%s pont, %s mp)%s',
      v_ev.title,
      v_overall_leader.p_name,
      v_overall_leader.score,
      v_ev.question_count,
      round((v_overall_leader.dur_ms / 1000.0)::numeric, 1),
      CASE
        WHEN v_hourly_count > 0 THEN format(
          ' • Elmúlt óra legjobbja (%s új kitöltés): %s (%s/%s pont, %s mp)',
          v_hourly_count,
          v_hourly_leader.p_name,
          v_hourly_leader.score,
          v_ev.question_count,
          round((v_hourly_leader.dur_ms / 1000.0)::numeric, 1)
        )
        ELSE ''
      END
    );

    INSERT INTO public.quiz_event_hourly_notifications (
      event_id,
      hour_bucket,
      hourly_winner_name,
      hourly_winner_score,
      hourly_winner_duration_ms,
      hourly_completions_count,
      overall_winner_name,
      overall_winner_score,
      overall_winner_duration_ms,
      overall_completions_count,
      summary_text
    )
    VALUES (
      v_ev.id,
      CASE WHEN p_force_current_hour THEN now() ELSE v_bucket_start END,
      v_hourly_leader.p_name,
      v_hourly_leader.score,
      v_hourly_leader.dur_ms,
      v_hourly_count,
      v_overall_leader.p_name,
      v_overall_leader.score,
      v_overall_leader.dur_ms,
      v_overall_count,
      v_summary
    )
    ON CONFLICT (event_id, hour_bucket) DO NOTHING
    RETURNING * INTO v_inserted_row;

    IF v_inserted_row.id IS NOT NULL THEN
      v_emitted := v_emitted || jsonb_build_array(to_jsonb(v_inserted_row));
    END IF;
  END LOOP;

  RETURN v_emitted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_quiz_event_state(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.start_quiz_event_submission(uuid, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_quiz_event_submission(uuid, text, integer, text, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_and_emit_quiz_hourly_leaders(boolean) TO authenticated;

-- Optional pg_cron schedule if pg_cron extension is enabled in Supabase
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('hunor_quiz_hourly_leaders')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'hunor_quiz_hourly_leaders');

    PERFORM cron.schedule(
      'hunor_quiz_hourly_leaders',
      '0 * * * *',
      $cron$SELECT public.check_and_emit_quiz_hourly_leaders(false);$cron$
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- Ignore if pg_cron is not installed; client/portal hourly check handles it seamlessly
  NULL;
END;
$$;

-- Also fix the minor 1-letter typo in Q-005 explanation if still present
UPDATE public.quiz_questions
SET explanation = replace(explanation, 'ellenőrzni', 'ellenőrizni')
WHERE explanation LIKE '%ellenőrzni%';

NOTIFY pgrst, 'reload schema';

COMMIT;
