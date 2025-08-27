-- ============================================================================
-- Enhanced User Profiles Migration Verification Script
-- Run this script after deploying the enhanced profiles migration
-- All tests should pass for a successful deployment
-- ============================================================================

-- Start verification
DO $$
DECLARE
  test_count INTEGER := 0;
  passed_count INTEGER := 0;
  test_name TEXT;
  test_result BOOLEAN;
  test_message TEXT;
BEGIN
  RAISE NOTICE '============================================================================';
  RAISE NOTICE 'ENHANCED USER PROFILES MIGRATION VERIFICATION';
  RAISE NOTICE 'Starting verification at: %', NOW();
  RAISE NOTICE '============================================================================';

  -- Test 1: Verify new columns exist in user_profiles
  test_count := test_count + 1;
  test_name := 'New user_profiles columns exist';
  
  SELECT COUNT(*) = 8 INTO test_result
  FROM information_schema.columns 
  WHERE table_name = 'user_profiles' 
  AND table_schema = 'public'
  AND column_name IN ('bio', 'phone', 'ffa_chapter', 'ffa_degree', 'ffa_state', 'member_since', 'profile_image_url', 'address');
  
  IF test_result THEN
    passed_count := passed_count + 1;
    RAISE NOTICE '✅ TEST %: % - PASSED', test_count, test_name;
  ELSE
    RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
    RAISE NOTICE '   Expected 8 new columns, check column creation';
  END IF;

  -- Test 2: Verify new tables were created
  test_count := test_count + 1;
  test_name := 'New tables created';
  
  SELECT COUNT(*) = 5 INTO test_result
  FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name IN ('ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills');
  
  IF test_result THEN
    passed_count := passed_count + 1;
    RAISE NOTICE '✅ TEST %: % - PASSED', test_count, test_name;
  ELSE
    RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
    RAISE NOTICE '   Expected 5 new tables, check table creation';
  END IF;

  -- Test 3: Verify FFA degrees sample data
  test_count := test_count + 1;
  test_name := 'FFA degrees sample data inserted';
  
  SELECT COUNT(*) >= 5 INTO test_result FROM ffa_degrees WHERE is_active = TRUE;
  
  IF test_result THEN
    passed_count := passed_count + 1;
    RAISE NOTICE '✅ TEST %: % - PASSED', test_count, test_name;
  ELSE
    RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
    RAISE NOTICE '   Expected at least 5 FFA degrees, check data insertion';
  END IF;

  -- Test 4: Verify skills catalog sample data
  test_count := test_count + 1;
  test_name := 'Skills catalog sample data inserted';
  
  SELECT COUNT(*) >= 10 INTO test_result FROM skills_catalog WHERE is_active = TRUE;
  
  IF test_result THEN
    passed_count := passed_count + 1;
    RAISE NOTICE '✅ TEST %: % - PASSED', test_count, test_name;
  ELSE
    RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
    RAISE NOTICE '   Expected at least 10 skills, check data insertion';
  END IF;

  -- Test 5: Verify FFA chapters sample data
  test_count := test_count + 1;
  test_name := 'FFA chapters sample data inserted';
  
  SELECT COUNT(*) >= 5 INTO test_result FROM ffa_chapters WHERE is_active = TRUE;
  
  IF test_result THEN
    passed_count := passed_count + 1;
    RAISE NOTICE '✅ TEST %: % - PASSED', test_count, test_name;
  ELSE
    RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
    RAISE NOTICE '   Expected at least 5 FFA chapters, check data insertion';
  END IF;

  -- Test 6: Verify validation functions work
  test_count := test_count + 1;
  test_name := 'Validation functions operational';
  
  SELECT 
    validate_phone('555-123-4567') = TRUE AND
    validate_phone('invalid') = FALSE AND
    validate_state_code('NE') = TRUE AND
    validate_state_code('XX') = FALSE
  INTO test_result;
  
  IF test_result THEN
    passed_count := passed_count + 1;
    RAISE NOTICE '✅ TEST %: % - PASSED', test_count, test_name;
  ELSE
    RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
    RAISE NOTICE '   Validation functions not working correctly';
  END IF;

  -- Test 7: Verify profile completion function
  test_count := test_count + 1;
  test_name := 'Profile completion function operational';
  
  BEGIN
    SELECT calculate_profile_completion((SELECT id FROM user_profiles LIMIT 1)) IS NOT NULL INTO test_result;
    
    IF test_result THEN
      passed_count := passed_count + 1;
      RAISE NOTICE '✅ TEST %: % - PASSED', test_count, test_name;
    ELSE
      RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
      RAISE NOTICE '   Profile completion function returned NULL';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      test_result := FALSE;
      RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
      RAISE NOTICE '   Profile completion function error: %', SQLERRM;
  END;

  -- Test 8: Verify RLS policies are active
  test_count := test_count + 1;
  test_name := 'RLS policies created for new tables';
  
  SELECT COUNT(*) >= 5 INTO test_result
  FROM pg_policies 
  WHERE schemaname = 'public' 
  AND tablename IN ('ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills');
  
  IF test_result THEN
    passed_count := passed_count + 1;
    RAISE NOTICE '✅ TEST %: % - PASSED', test_count, test_name;
  ELSE
    RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
    RAISE NOTICE '   Expected RLS policies for new tables, check policy creation';
  END IF;

  -- Test 9: Verify indexes were created
  test_count := test_count + 1;
  test_name := 'Performance indexes created';
  
  SELECT COUNT(*) >= 10 INTO test_result
  FROM pg_indexes 
  WHERE schemaname = 'public' 
  AND tablename IN ('user_profiles', 'ffa_chapters', 'user_ffa_progress', 'user_skills')
  AND indexname LIKE 'idx_%';
  
  IF test_result THEN
    passed_count := passed_count + 1;
    RAISE NOTICE '✅ TEST %: % - PASSED', test_count, test_name;
  ELSE
    RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
    RAISE NOTICE '   Expected performance indexes, check index creation';
  END IF;

  -- Test 10: Verify views were created
  test_count := test_count + 1;
  test_name := 'Helper views created';
  
  SELECT COUNT(*) = 3 INTO test_result
  FROM information_schema.views 
  WHERE table_schema = 'public' 
  AND table_name IN ('user_profile_summary', 'ffa_degree_progress_view', 'user_skills_summary');
  
  IF test_result THEN
    passed_count := passed_count + 1;
    RAISE NOTICE '✅ TEST %: % - PASSED', test_count, test_name;
  ELSE
    RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
    RAISE NOTICE '   Expected 3 helper views, check view creation';
  END IF;

  -- Test 11: Verify triggers were created
  test_count := test_count + 1;
  test_name := 'Update triggers operational';
  
  SELECT COUNT(*) >= 1 INTO test_result
  FROM information_schema.triggers 
  WHERE event_object_schema = 'public'
  AND trigger_name LIKE '%ffa_progress%';
  
  IF test_result THEN
    passed_count := passed_count + 1;
    RAISE NOTICE '✅ TEST %: % - PASSED', test_count, test_name;
  ELSE
    RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
    RAISE NOTICE '   Expected FFA progress trigger, check trigger creation';
  END IF;

  -- Test 12: Verify constraint validations
  test_count := test_count + 1;
  test_name := 'Data validation constraints active';
  
  BEGIN
    -- Try to insert invalid phone number (should fail)
    INSERT INTO user_profiles (id, email, phone) 
    VALUES (gen_random_uuid(), 'test@invalid.com', 'invalid-phone');
    
    -- If we get here, constraint didn't work
    test_result := FALSE;
    RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
    RAISE NOTICE '   Phone validation constraint not working';
    
    -- Cleanup the invalid record
    DELETE FROM user_profiles WHERE email = 'test@invalid.com';
    
  EXCEPTION
    WHEN check_violation THEN
      -- This is expected - constraint is working
      test_result := TRUE;
      passed_count := passed_count + 1;
      RAISE NOTICE '✅ TEST %: % - PASSED', test_count, test_name;
    WHEN OTHERS THEN
      test_result := FALSE;
      RAISE NOTICE '❌ TEST %: % - FAILED', test_count, test_name;
      RAISE NOTICE '   Unexpected error: %', SQLERRM;
  END;

  -- Summary
  RAISE NOTICE '============================================================================';
  RAISE NOTICE 'VERIFICATION SUMMARY';
  RAISE NOTICE 'Total tests: %', test_count;
  RAISE NOTICE 'Passed: %', passed_count;
  RAISE NOTICE 'Failed: %', test_count - passed_count;
  
  IF passed_count = test_count THEN
    RAISE NOTICE '🎉 ALL TESTS PASSED - MIGRATION SUCCESSFUL!';
    RAISE NOTICE 'The enhanced user profiles system is ready for use.';
  ELSE
    RAISE NOTICE '⚠️  SOME TESTS FAILED - REVIEW REQUIRED';
    RAISE NOTICE 'Check the failed tests above and fix issues before proceeding.';
  END IF;
  
  RAISE NOTICE 'Verification completed at: %', NOW();
  RAISE NOTICE '============================================================================';

END $$;

-- ============================================================================
-- DETAILED VERIFICATION QUERIES
-- Run these individually for more detailed diagnostics
-- ============================================================================

-- Check user_profiles schema changes
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check new table structures
DO $$
DECLARE
  table_name TEXT;
  table_list TEXT[] := ARRAY['ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills'];
BEGIN
  FOREACH table_name IN ARRAY table_list
  LOOP
    RAISE NOTICE '';
    RAISE NOTICE 'Table: %', table_name;
    RAISE NOTICE '----------------------------------------';
    
    FOR rec IN 
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = table_name 
      AND table_schema = 'public'
      ORDER BY ordinal_position
    LOOP
      RAISE NOTICE '  %: % (%)', rec.column_name, rec.data_type, 
        CASE WHEN rec.is_nullable = 'YES' THEN 'NULL' ELSE 'NOT NULL' END;
    END LOOP;
  END LOOP;
END $$;

-- Sample data verification
SELECT 'FFA Degrees' as data_type, degree_name, degree_level 
FROM ffa_degrees 
WHERE is_active = TRUE 
ORDER BY degree_level

UNION ALL

SELECT 'FFA Chapters', chapter_name, state_code::text 
FROM ffa_chapters 
WHERE is_active = TRUE 
LIMIT 5

UNION ALL

SELECT 'Skills Catalog', skill_name, category 
FROM skills_catalog 
WHERE is_active = TRUE 
LIMIT 5;

-- Function testing
SELECT 
  'validate_phone' as function_name,
  '555-123-4567' as test_input,
  validate_phone('555-123-4567') as result,
  'Should be TRUE' as expected

UNION ALL

SELECT 
  'validate_phone',
  'invalid-phone',
  validate_phone('invalid-phone'),
  'Should be FALSE'

UNION ALL

SELECT 
  'validate_state_code',
  'NE',
  validate_state_code('NE'),
  'Should be TRUE'

UNION ALL

SELECT 
  'validate_state_code', 
  'XX',
  validate_state_code('XX'),
  'Should be FALSE';

-- Profile completion test (if users exist)
SELECT 
  email,
  calculate_profile_completion(id) as completion_percentage,
  CASE 
    WHEN bio IS NOT NULL AND LENGTH(bio) > 0 THEN 'Has bio' 
    ELSE 'No bio' 
  END as bio_status,
  CASE 
    WHEN phone IS NOT NULL THEN 'Has phone' 
    ELSE 'No phone' 
  END as phone_status,
  CASE 
    WHEN ffa_chapter IS NOT NULL THEN 'Has chapter' 
    ELSE 'No chapter' 
  END as chapter_status
FROM user_profiles 
LIMIT 5;

-- RLS Policy verification
SELECT 
  tablename,
  policyname,
  cmd,
  permissive,
  SUBSTRING(qual, 1, 50) as condition_preview
FROM pg_policies 
WHERE schemaname = 'public'
AND tablename IN ('ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills')
ORDER BY tablename, policyname;

-- Index verification
SELECT 
  tablename,
  indexname,
  indexdef
FROM pg_indexes 
WHERE schemaname = 'public'
AND tablename IN ('user_profiles', 'ffa_chapters', 'user_ffa_progress', 'user_skills')
AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- View verification
SELECT 
  table_name,
  CASE 
    WHEN table_name = 'user_profile_summary' THEN 'User profile with completion percentage'
    WHEN table_name = 'ffa_degree_progress_view' THEN 'FFA degree progress tracking'
    WHEN table_name = 'user_skills_summary' THEN 'Skills summary by category'
    ELSE 'Unknown view'
  END as description
FROM information_schema.views 
WHERE table_schema = 'public' 
AND table_name IN ('user_profile_summary', 'ffa_degree_progress_view', 'user_skills_summary')
ORDER BY table_name;

-- Configuration verification
SELECT 
  key,
  value,
  description,
  updated_at
FROM security_config 
WHERE key IN ('schema_version', 'migration_date', 'profile_fields_count')
ORDER BY key;

-- Final success message
SELECT 
  'Enhanced User Profiles Migration Verification Complete' as status,
  NOW() as completed_at,
  'Ready for production use' as next_step;