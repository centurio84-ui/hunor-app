-- ============================================================================
-- MAKE REWARD OPT-IN BY DEFAULT (OFF & EMPTY UNTIL EXPLICITLY CONFIGURED)
-- ============================================================================
BEGIN;

ALTER TABLE public.quiz_events
  ALTER COLUMN reward_enabled SET DEFAULT false;

ALTER TABLE public.quiz_events
  ALTER COLUMN reward_name SET DEFAULT '';

-- Clean up any previously auto-populated 'Ajándék nyeremény' placeholder
UPDATE public.quiz_events
SET reward_enabled = false,
    reward_name = ''
WHERE reward_name = 'Ajándék nyeremény';

NOTIFY pgrst, 'reload schema';

COMMIT;
