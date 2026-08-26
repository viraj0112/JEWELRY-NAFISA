-- Evaluate auth helpers once per statement rather than once per row.
-- ALTER POLICY preserves the existing roles, commands, and policy logic.
DO $$
DECLARE
  policy_record record;
  optimized_qual text;
  optimized_check text;
BEGIN
  FOR policy_record IN
    SELECT schemaname, tablename, policyname, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND (
        COALESCE(qual, '') ~* 'auth\.(uid|jwt)\s*\('
        OR COALESCE(with_check, '') ~* 'auth\.(uid|jwt)\s*\('
      )
  LOOP
    optimized_qual := regexp_replace(
      regexp_replace(
        policy_record.qual,
        'auth\.uid\s*\(\s*\)',
        '(select auth.uid())',
        'gi'
      ),
      'auth\.jwt\s*\(\s*\)',
      '(select auth.jwt())',
      'gi'
    );

    optimized_check := regexp_replace(
      regexp_replace(
        policy_record.with_check,
        'auth\.uid\s*\(\s*\)',
        '(select auth.uid())',
        'gi'
      ),
      'auth\.jwt\s*\(\s*\)',
      '(select auth.jwt())',
      'gi'
    );

    IF optimized_qual IS NOT NULL THEN
      EXECUTE format(
        'ALTER POLICY %I ON %I.%I USING (%s)',
        policy_record.policyname,
        policy_record.schemaname,
        policy_record.tablename,
        optimized_qual
      );
    END IF;

    IF optimized_check IS NOT NULL THEN
      EXECUTE format(
        'ALTER POLICY %I ON %I.%I WITH CHECK (%s)',
        policy_record.policyname,
        policy_record.schemaname,
        policy_record.tablename,
        optimized_check
      );
    END IF;
  END LOOP;
END
$$;
