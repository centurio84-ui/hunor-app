-- ============================================================================
-- FACEBOOK CLICKABLE POSTER CARDS: PUBLIC STORAGE BUCKET FOR RENDERED POSTERS
-- ============================================================================
BEGIN;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'quiz-posters',
  'quiz-posters',
  true,
  10485760,
  ARRAY['image/png', 'image/jpeg', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
  SET public = true,
      file_size_limit = 10485760,
      allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/webp'];

DROP POLICY IF EXISTS "Public read quiz posters" ON storage.objects;
CREATE POLICY "Public read quiz posters"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'quiz-posters');

DROP POLICY IF EXISTS "Authenticated upload quiz posters" ON storage.objects;
CREATE POLICY "Authenticated upload quiz posters"
  ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'quiz-posters');

DROP POLICY IF EXISTS "Authenticated update quiz posters" ON storage.objects;
CREATE POLICY "Authenticated update quiz posters"
  ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'quiz-posters')
  WITH CHECK (bucket_id = 'quiz-posters');

DROP POLICY IF EXISTS "Authenticated delete quiz posters" ON storage.objects;
CREATE POLICY "Authenticated delete quiz posters"
  ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'quiz-posters');

COMMIT;
