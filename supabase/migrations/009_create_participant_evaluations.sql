-- Migration: 009_create_participant_evaluations.sql
-- Beavatkozói önértékelések (T0 művelet előtti, T1 művelet utáni) tábla és jogosultságok

CREATE TABLE IF NOT EXISTS public.participant_evaluations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  form_type text NOT NULL CHECK (form_type IN ('T0', 'T1')),
  anon_token text NOT NULL,
  responses jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Indexek a gyors szűréshez token és típus szerint
CREATE INDEX IF NOT EXISTS idx_participant_evaluations_token
  ON public.participant_evaluations (anon_token);

CREATE INDEX IF NOT EXISTS idx_participant_evaluations_form_type
  ON public.participant_evaluations (form_type);

CREATE INDEX IF NOT EXISTS idx_participant_evaluations_created_at
  ON public.participant_evaluations (created_at DESC);

-- Row Level Security (RLS) bekapcsolása
ALTER TABLE public.participant_evaluations ENABLE ROW LEVEL SECURITY;

-- 1. Beszúrás (INSERT): Bárki (anonim / anon role és autentikált felhasználó egyaránt) beküldhet önértékelést
CREATE POLICY "Anyone can insert participant evaluations"
  ON public.participant_evaluations
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- 2. Olvasás (SELECT): Csak autentikált felhasználók (elemzők, adminok, vezetők) olvashatják
CREATE POLICY "Authenticated users can read participant evaluations"
  ON public.participant_evaluations
  FOR SELECT
  TO authenticated
  USING (true);
