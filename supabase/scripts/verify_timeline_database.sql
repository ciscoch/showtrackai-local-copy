-- ============================================================================
-- Timeline Database Verification Script
-- Purpose: Verify all database components are ready for APP-125
-- Run this after applying migrations to ensure everything is set up correctly
-- ============================================================================

-- Enable detailed output
\timing on
\x auto

-- ============================================================================
-- 1. TABLE STRUCTURE VERIFICATION
-- ============================================================================

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE '1. VERIFYING TABLE STRUCTURES';
RAISE NOTICE '========================================';

-- Check journal_entries columns
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'journal_entries'
  AND column_name IN ('id', 'user_id', 'title', 'description', 'content', 
                       'entry_date', 'category', 'animal_id', 'duration', 
                       'quality_score', 'financial_value', 'tags', 'photos')
ORDER BY ordinal_position;

-- Check expenses columns
SELECT 
  column_name, 
  data_type, 
  is_nullable
FROM information_schema.columns
WHERE table_name = 'expenses'
  AND column_name IN ('id', 'user_id', 'title', 'description', 'amount', 
                       'date', 'category', 'animal_id', 'vendor_name', 
                       'payment_method', 'is_paid', 'tags', 'receipt_url')
ORDER BY ordinal_position;

-- ============================================================================
-- 2. INDEX VERIFICATION
-- ============================================================================

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE '2. VERIFYING INDEXES';
RAISE NOTICE '========================================';

-- List all timeline-related indexes
SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename IN ('journal_entries', 'expenses', 'animals')
  AND (indexname LIKE '%timeline%' 
       OR indexname LIKE '%user%date%'
       OR indexname LIKE '%date%'
       OR indexname LIKE '%recent%')
ORDER BY tablename, indexname;

-- Check index usage statistics
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan as index_scans,
  idx_tup_read as tuples_read,
  idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE tablename IN ('journal_entries', 'expenses')
ORDER BY idx_scan DESC;

-- ============================================================================
-- 3. ROW LEVEL SECURITY VERIFICATION
-- ============================================================================

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE '3. VERIFYING ROW LEVEL SECURITY';
RAISE NOTICE '========================================';

-- Check RLS status
SELECT 
  schemaname,
  tablename,
  CASE WHEN rowsecurity THEN '✅ ENABLED' ELSE '❌ DISABLED' END as rls_status
FROM pg_tables
WHERE tablename IN ('journal_entries', 'expenses', 'animals')
ORDER BY tablename;

-- List RLS policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual IS NOT NULL as has_using_clause,
  with_check IS NOT NULL as has_check_clause
FROM pg_policies
WHERE tablename IN ('journal_entries', 'expenses')
ORDER BY tablename, policyname;

-- ============================================================================
-- 4. VIEW AND FUNCTION VERIFICATION
-- ============================================================================

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE '4. VERIFYING VIEWS AND FUNCTIONS';
RAISE NOTICE '========================================';

-- Check if unified_timeline view exists
SELECT 
  'unified_timeline' as object_name,
  'VIEW' as object_type,
  CASE WHEN COUNT(*) > 0 THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
FROM information_schema.views
WHERE table_name = 'unified_timeline'
UNION ALL
-- Check for optimized query function
SELECT 
  'get_timeline_items_optimized' as object_name,
  'FUNCTION' as object_type,
  CASE WHEN COUNT(*) > 0 THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
FROM information_schema.routines
WHERE routine_name = 'get_timeline_items_optimized'
UNION ALL
-- Check for stats function
SELECT 
  'get_timeline_stats' as object_name,
  'FUNCTION' as object_type,
  CASE WHEN COUNT(*) > 0 THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
FROM information_schema.routines
WHERE routine_name = 'get_timeline_stats';

-- ============================================================================
-- 5. PERFORMANCE TESTING
-- ============================================================================

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE '5. PERFORMANCE TESTING';
RAISE NOTICE '========================================';

-- Test unified timeline query performance
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT * FROM unified_timeline
WHERE user_id = (SELECT id FROM auth.users LIMIT 1)
ORDER BY date DESC, timestamp DESC
LIMIT 20;

-- Test timeline function performance
DO $$
DECLARE
  start_time TIMESTAMP;
  end_time TIMESTAMP;
  duration INTERVAL;
  test_user_id UUID;
BEGIN
  -- Get a test user
  SELECT id INTO test_user_id FROM auth.users LIMIT 1;
  
  IF test_user_id IS NULL THEN
    RAISE NOTICE 'No users found for testing';
    RETURN;
  END IF;
  
  -- Test timeline query function
  start_time := clock_timestamp();
  PERFORM * FROM get_timeline_items_optimized(
    test_user_id, 
    20, 
    0, 
    CURRENT_DATE - INTERVAL '30 days',
    CURRENT_DATE
  );
  end_time := clock_timestamp();
  duration := end_time - start_time;
  
  RAISE NOTICE 'Timeline query execution time: %ms', 
    EXTRACT(MILLISECONDS FROM duration);
  
  -- Test stats function
  start_time := clock_timestamp();
  PERFORM get_timeline_stats(test_user_id, 30);
  end_time := clock_timestamp();
  duration := end_time - start_time;
  
  RAISE NOTICE 'Stats query execution time: %ms', 
    EXTRACT(MILLISECONDS FROM duration);
END;
$$;

-- ============================================================================
-- 6. DATA INTEGRITY CHECKS
-- ============================================================================

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE '6. DATA INTEGRITY CHECKS';
RAISE NOTICE '========================================';

-- Check for orphaned animal references
SELECT 
  'Journal entries with invalid animals' as check_name,
  COUNT(*) as count
FROM journal_entries je
LEFT JOIN animals a ON je.animal_id = a.id
WHERE je.animal_id IS NOT NULL AND a.id IS NULL
UNION ALL
SELECT 
  'Expenses with invalid animals' as check_name,
  COUNT(*) as count
FROM expenses e
LEFT JOIN animals a ON e.animal_id = a.id
WHERE e.animal_id IS NOT NULL AND a.id IS NULL;

-- Check for missing user references
SELECT 
  'Journal entries with invalid users' as check_name,
  COUNT(*) as count
FROM journal_entries je
LEFT JOIN auth.users u ON je.user_id = u.id
WHERE je.user_id IS NOT NULL AND u.id IS NULL
UNION ALL
SELECT 
  'Expenses with invalid users' as check_name,
  COUNT(*) as count
FROM expenses e
LEFT JOIN auth.users u ON e.user_id = u.id
WHERE e.user_id IS NOT NULL AND u.id IS NULL;

-- ============================================================================
-- 7. SAMPLE DATA DISTRIBUTION
-- ============================================================================

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE '7. DATA DISTRIBUTION ANALYSIS';
RAISE NOTICE '========================================';

-- Analyze data distribution for optimization
WITH data_stats AS (
  SELECT 
    'journal_entries' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT animal_id) as unique_animals,
    COUNT(DISTINCT category) as unique_categories,
    MIN(entry_date) as earliest_date,
    MAX(entry_date) as latest_date
  FROM journal_entries
  UNION ALL
  SELECT 
    'expenses' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT animal_id) as unique_animals,
    COUNT(DISTINCT category) as unique_categories,
    MIN(date::date) as earliest_date,
    MAX(date::date) as latest_date
  FROM expenses
)
SELECT * FROM data_stats;

-- ============================================================================
-- 8. PERFORMANCE RECOMMENDATIONS
-- ============================================================================

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE '8. PERFORMANCE ANALYSIS';
RAISE NOTICE '========================================';

-- Run performance analysis function if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_name = 'analyze_timeline_performance'
  ) THEN
    RAISE NOTICE 'Running performance analysis...';
    
    -- Create temp table to store results
    CREATE TEMP TABLE IF NOT EXISTS perf_results AS
    SELECT * FROM analyze_timeline_performance();
    
    -- Display results
    PERFORM * FROM perf_results;
    
    DROP TABLE IF EXISTS perf_results;
  ELSE
    RAISE NOTICE 'Performance analysis function not found';
  END IF;
END;
$$;

-- ============================================================================
-- FINAL SUMMARY
-- ============================================================================

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE 'VERIFICATION SUMMARY';
RAISE NOTICE '========================================';

WITH verification_summary AS (
  SELECT 
    'Tables' as component,
    COUNT(*) as count,
    CASE WHEN COUNT(*) >= 3 THEN '✅' ELSE '❌' END as status
  FROM information_schema.tables
  WHERE table_name IN ('journal_entries', 'expenses', 'animals')
  UNION ALL
  SELECT 
    'Indexes' as component,
    COUNT(*) as count,
    CASE WHEN COUNT(*) >= 10 THEN '✅' ELSE '⚠️' END as status
  FROM pg_indexes
  WHERE tablename IN ('journal_entries', 'expenses')
  UNION ALL
  SELECT 
    'RLS Policies' as component,
    COUNT(*) as count,
    CASE WHEN COUNT(*) >= 8 THEN '✅' ELSE '⚠️' END as status
  FROM pg_policies
  WHERE tablename IN ('journal_entries', 'expenses')
  UNION ALL
  SELECT 
    'Views' as component,
    COUNT(*) as count,
    CASE WHEN COUNT(*) >= 1 THEN '✅' ELSE '❌' END as status
  FROM information_schema.views
  WHERE table_name LIKE '%timeline%'
  UNION ALL
  SELECT 
    'Functions' as component,
    COUNT(*) as count,
    CASE WHEN COUNT(*) >= 2 THEN '✅' ELSE '⚠️' END as status
  FROM information_schema.routines
  WHERE routine_name LIKE '%timeline%'
)
SELECT 
  component,
  count,
  status,
  CASE 
    WHEN status = '✅' THEN 'Ready'
    WHEN status = '⚠️' THEN 'Needs Review'
    ELSE 'Missing Components'
  END as assessment
FROM verification_summary
ORDER BY component;

RAISE NOTICE '';
RAISE NOTICE 'Verification complete! Check results above.';
RAISE NOTICE '========================================';

-- Reset output format
\x off
\timing off