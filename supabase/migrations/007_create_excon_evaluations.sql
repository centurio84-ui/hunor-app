-- Migration: 007_create_excon_evaluations.sql
-- EXCON (Értékelő) modul táblája és jogosultságai

CREATE TABLE IF NOT EXISTS public.excon_evaluations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  evaluator_name text NOT NULL,
  checkpoint_code text NOT NULL,
  score smallint NOT NULL CHECK (score IN (0, 1, 2)),
  comment text
);

-- Indexek a gyors szűréshez és lekérdezésekhez
CREATE INDEX IF NOT EXISTS idx_excon_evaluations_checkpoint
  ON public.excon_evaluations (checkpoint_code);

CREATE INDEX IF NOT EXISTS idx_excon_evaluations_created_at
  ON public.excon_evaluations (created_at DESC);

-- RLS bekapcsolása
ALTER TABLE public.excon_evaluations ENABLE ROW LEVEL SECURITY;

-- Autentikált felhasználók beszúrhatnak értékelést
CREATE POLICY "Authenticated users can insert evaluations"
  ON public.excon_evaluations
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Autentikált felhasználók és adminok / vezetők olvashatják az értékeléseket
CREATE POLICY "Authenticated users can read evaluations"
  ON public.excon_evaluations
  FOR SELECT
  TO authenticated
  USING (true);
