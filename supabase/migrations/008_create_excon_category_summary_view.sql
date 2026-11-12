-- Migration: 008_create_excon_category_summary_view.sql
-- EXCON kategóriánkénti összegző VIEW

CREATE OR REPLACE VIEW public.excon_category_summary AS
WITH base AS (
  SELECT
    id,
    created_at,
    evaluator_name,
    checkpoint_code,
    score,
    -- Kategória meghatározása: pl. OP-K9-01 -> OP-K9, III/C-1 -> III/C, vagy a kötőjel előtti rész
    CASE
      WHEN checkpoint_code LIKE 'OP-K9%' THEN 'OP-K9'
      WHEN checkpoint_code LIKE 'III/C%' THEN 'III/C'
      WHEN position('-' in checkpoint_code) > 0 THEN split_part(checkpoint_code, '-', 1)
      WHEN position('/' in checkpoint_code) > 0 THEN split_part(checkpoint_code, '/', 1)
      ELSE checkpoint_code
    END AS category_code
  FROM public.excon_evaluations
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

-- Olvasási jogosultság biztosítása az autentikált felhasználóknak
GRANT SELECT ON public.excon_category_summary TO authenticated;
