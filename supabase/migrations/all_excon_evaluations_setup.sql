-- ============================================================================
-- HUNOR RESCUE PLATFORM: EXCON & ÖNÉRTÉKELÉS ADATBÁZIS SÉMA ÉS JOGOSULTSÁGOK
-- Futtasd ezt a Supabase SQL Editorban:
-- https://supabase.com/dashboard/project/embicteneumubwlqqfik/sql
-- ============================================================================

-- 1. EXCON Értékelések tábla
CREATE TABLE IF NOT EXISTS public.excon_evaluations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  event_id uuid REFERENCES public.events(id) ON DELETE SET NULL,
  evaluator_name text NOT NULL,
  checkpoint_code text NOT NULL,
  score smallint NOT NULL CHECK (score IN (-1, 0, 1, 2)),
  comment text
);

CREATE INDEX IF NOT EXISTS idx_excon_evaluations_checkpoint ON public.excon_evaluations (checkpoint_code);
CREATE INDEX IF NOT EXISTS idx_excon_evaluations_created_at ON public.excon_evaluations (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_excon_evaluations_event_id ON public.excon_evaluations (event_id);

ALTER TABLE public.excon_evaluations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can insert evaluations" ON public.excon_evaluations;
CREATE POLICY "Anyone can insert evaluations" ON public.excon_evaluations
  FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can read evaluations" ON public.excon_evaluations;
CREATE POLICY "Anyone can read evaluations" ON public.excon_evaluations
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Anyone can delete evaluations" ON public.excon_evaluations;
CREATE POLICY "Anyone can delete evaluations" ON public.excon_evaluations
  FOR DELETE TO anon, authenticated USING (true);

-- 2. EXCON Kategória Összegző Nézet (View)
CREATE OR REPLACE VIEW public.excon_category_summary AS
WITH base AS (
  SELECT
    id,
    created_at,
    evaluator_name,
    checkpoint_code,
    score,
    CASE
      WHEN checkpoint_code LIKE 'OP-K9%' THEN 'OP-K9'
      WHEN checkpoint_code LIKE 'III/C%' THEN 'III/C'
      WHEN position('-' in checkpoint_code) > 0 THEN split_part(checkpoint_code, '-', 1)
      WHEN position('/' in checkpoint_code) > 0 THEN split_part(checkpoint_code, '/', 1)
      ELSE checkpoint_code
    END AS category_code
  FROM public.excon_evaluations
  WHERE score >= 0
)
SELECT
  category_code,
  COUNT(*)::int AS evaluation_count,
  (COUNT(*) * 2)::int AS max_possible_score,
  COALESCE(SUM(score), 0)::int AS total_achieved_score,
  ROUND(
    (COALESCE(SUM(score), 0)::numeric / NULLIF(COUNT(*) * 2, 0)::numeric) * 100,
    2
  )::float AS performance_percentage
FROM base
GROUP BY category_code
ORDER BY performance_percentage DESC, category_code ASC;

GRANT SELECT ON public.excon_category_summary TO anon, authenticated;

-- 3. Beavatkozói Önértékelések (T0 és T1)
CREATE TABLE IF NOT EXISTS public.participant_evaluations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  event_id uuid REFERENCES public.events(id) ON DELETE SET NULL,
  form_type text NOT NULL CHECK (form_type IN ('T0', 'T1')),
  anon_token text NOT NULL,
  responses jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_participant_evaluations_token ON public.participant_evaluations (anon_token);
CREATE INDEX IF NOT EXISTS idx_participant_evaluations_form_type ON public.participant_evaluations (form_type);
CREATE INDEX IF NOT EXISTS idx_participant_evaluations_created_at ON public.participant_evaluations (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_participant_evaluations_event_id ON public.participant_evaluations (event_id);

ALTER TABLE public.participant_evaluations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can insert participant evaluations" ON public.participant_evaluations;
CREATE POLICY "Anyone can insert participant evaluations" ON public.participant_evaluations
  FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can read participant evaluations" ON public.participant_evaluations;
CREATE POLICY "Anyone can read participant evaluations" ON public.participant_evaluations
  FOR SELECT TO anon, authenticated USING (true);

-- 4. Értékelő Következtetések Tábla (Vezetői zárójelentés)
CREATE TABLE IF NOT EXISTS public.event_conclusions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  author_name text NOT NULL,
  conclusion_text text NOT NULL,
  strengths text,
  improvements text,
  recommendations text,
  CONSTRAINT event_conclusions_event_unique UNIQUE (event_id)
);

CREATE INDEX IF NOT EXISTS idx_event_conclusions_event_id ON public.event_conclusions (event_id);

ALTER TABLE public.event_conclusions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can manage conclusions" ON public.event_conclusions;
CREATE POLICY "Anyone can manage conclusions" ON public.event_conclusions
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
