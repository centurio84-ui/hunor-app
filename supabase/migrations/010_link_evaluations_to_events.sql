-- Migration: 010_link_evaluations_to_events.sql
-- Értékelések (EXCON és T0/T1) eseményhez kapcsolása, valamint értékelő következtetések táblája

ALTER TABLE IF EXISTS public.excon_evaluations 
  ADD COLUMN IF NOT EXISTS event_id uuid REFERENCES public.events(id) ON DELETE SET NULL;

ALTER TABLE IF EXISTS public.participant_evaluations 
  ADD COLUMN IF NOT EXISTS event_id uuid REFERENCES public.events(id) ON DELETE SET NULL;

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

CREATE INDEX IF NOT EXISTS idx_excon_evaluations_event_id ON public.excon_evaluations(event_id);
CREATE INDEX IF NOT EXISTS idx_participant_evaluations_event_id ON public.participant_evaluations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_conclusions_event_id ON public.event_conclusions(event_id);

ALTER TABLE public.event_conclusions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read conclusions"
  ON public.event_conclusions FOR SELECT
  TO anon, authenticated USING (true);

CREATE POLICY "Authenticated users can insert conclusions"
  ON public.event_conclusions FOR INSERT
  TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update conclusions"
  ON public.event_conclusions FOR UPDATE
  TO authenticated USING (true) WITH CHECK (true);
