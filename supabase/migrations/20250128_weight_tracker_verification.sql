-- =====================================================================
-- Weight Tracker Schema Verification Script
-- =====================================================================
-- Run this script AFTER migration to verify successful deployment
-- Author: ShowTrackAI Database Team  
-- Date: 2025-01-28
-- =====================================================================

-- 1. CHECK ENUM TYPES
SELECT 
    'ENUM Types' as check_category,
    typname as type_name,
    array_to_string(enum_range(NULL::weight_unit), ', ') as values
FROM pg_type 
WHERE typname IN ('weight_unit', 'weight_status', 'measurement_method', 'goal_status')
    AND typtype = 'e'
ORDER BY typname;

-- 2. CHECK TABLES EXIST
SELECT 
    'Tables' as check_category,
    tablename,
    CASE 
        WHEN tablename IS NOT NULL THEN '✓ EXISTS'
        ELSE '✗ MISSING'
    END as status
FROM (
    SELECT unnest(ARRAY[
        'weights', 
        'weight_goals', 
        'weight_audit_log', 
        'weight_statistics_cache'
    ]) as expected_table
) e
LEFT JOIN pg_tables t ON t.tablename = e.expected_table AND t.schemaname = 'public'
ORDER BY expected_table;

-- 3. CHECK CRITICAL COLUMNS
SELECT 
    'Critical Columns' as check_category,
    c.table_name,
    c.column_name,
    c.data_type,
    c.is_nullable
FROM information_schema.columns c
WHERE c.table_schema = 'public' 
    AND c.table_name = 'weights'
    AND c.column_name IN ('id', 'animal_id', 'user_id', 'weight_value', 'measurement_date', 'adg')
ORDER BY c.table_name, c.ordinal_position;

-- 4. CHECK INDEXES
SELECT 
    'Indexes' as check_category,
    schemaname,
    tablename,
    indexname,
    CASE 
        WHEN indexname IS NOT NULL THEN '✓ EXISTS'
        ELSE '✗ MISSING'
    END as status
FROM pg_indexes
WHERE schemaname = 'public' 
    AND tablename IN ('weights', 'weight_goals', 'weight_audit_log', 'weight_statistics_cache')
ORDER BY tablename, indexname;

-- 5. CHECK VIEWS
SELECT 
    'Views' as check_category,
    viewname,
    CASE 
        WHEN viewname IS NOT NULL THEN '✓ EXISTS'
        ELSE '✗ MISSING'
    END as status
FROM pg_views
WHERE schemaname = 'public' 
    AND viewname IN (
        'v_latest_weights',
        'v_adg_calculations', 
        'v_weight_history',
        'v_active_weight_goals'
    )
ORDER BY viewname;

-- 6. CHECK TRIGGERS
SELECT 
    'Triggers' as check_category,
    event_object_table as table_name,
    trigger_name,
    event_manipulation as trigger_event,
    CASE 
        WHEN trigger_name IS NOT NULL THEN '✓ EXISTS'
        ELSE '✗ MISSING'
    END as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
    AND event_object_table IN ('weights', 'weight_goals')
ORDER BY event_object_table, trigger_name;

-- 7. CHECK RLS POLICIES
SELECT 
    'RLS Policies' as check_category,
    schemaname,
    tablename,
    policyname,
    cmd as operation,
    CASE 
        WHEN policyname IS NOT NULL THEN '✓ EXISTS'
        ELSE '✗ MISSING'
    END as status
FROM pg_policies
WHERE schemaname = 'public' 
    AND tablename IN ('weights', 'weight_goals', 'weight_audit_log', 'weight_statistics_cache')
ORDER BY tablename, policyname;

-- 8. CHECK RLS IS ENABLED
SELECT 
    'RLS Enabled' as check_category,
    schemaname,
    tablename,
    CASE rowsecurity 
        WHEN true THEN '✓ ENABLED'
        ELSE '✗ DISABLED'
    END as rls_status
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN ('weights', 'weight_goals', 'weight_audit_log', 'weight_statistics_cache')
ORDER BY tablename;

-- 9. CHECK FUNCTIONS
SELECT 
    'Functions' as check_category,
    routine_name as function_name,
    CASE 
        WHEN routine_name IS NOT NULL THEN '✓ EXISTS'
        ELSE '✗ MISSING'
    END as status
FROM information_schema.routines
WHERE routine_schema = 'public'
    AND routine_name IN (
        'calculate_weight_metrics',
        'update_weight_goal_progress',
        'log_weight_changes',
        'update_weight_statistics',
        'recalculate_weight_statistics',
        'get_weight_trend',
        'detect_weight_outliers',
        'cleanup_old_audit_logs',
        'recalculate_all_pending_statistics'
    )
ORDER BY routine_name;

-- 10. CHECK FOREIGN KEY CONSTRAINTS
SELECT 
    'Foreign Keys' as check_category,
    conname as constraint_name,
    conrelid::regclass as table_name,
    confrelid::regclass as foreign_table,
    CASE 
        WHEN conname IS NOT NULL THEN '✓ EXISTS'
        ELSE '✗ MISSING'
    END as status
FROM pg_constraint
WHERE contype = 'f'
    AND conrelid::regclass::text LIKE '%weight%'
ORDER BY conrelid::regclass::text, conname;

-- 11. TEST INSERT CAPABILITY (dry run - rolled back)
DO $$
BEGIN
    -- This will be rolled back, just testing constraints
    BEGIN
        INSERT INTO public.weights (
            animal_id, 
            user_id, 
            recorded_by,
            weight_value,
            weight_unit,
            measurement_date,
            measurement_method
        ) VALUES (
            gen_random_uuid(),  -- fake animal_id
            gen_random_uuid(),  -- fake user_id
            gen_random_uuid(),  -- fake recorded_by
            150.5,
            'lb',
            CURRENT_DATE,
            'digital_scale'
        );
        RAISE NOTICE 'Weight insert test: ✓ PASSED (constraints working)';
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'Weight insert test: ✓ PASSED (foreign key constraints working)';
        WHEN OTHERS THEN
            RAISE NOTICE 'Weight insert test: ✗ FAILED - %', SQLERRM;
    END;
    -- Rollback the test insert
    ROLLBACK;
END $$;

-- 12. SUMMARY REPORT
SELECT 
    '=== DEPLOYMENT SUMMARY ===' as report,
    COUNT(DISTINCT tablename) as tables_created,
    COUNT(DISTINCT indexname) as indexes_created,
    COUNT(DISTINCT viewname) as views_created,
    COUNT(DISTINCT routine_name) as functions_created
FROM (
    SELECT tablename, NULL as indexname, NULL as viewname, NULL as routine_name FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE '%weight%'
    UNION ALL
    SELECT NULL, indexname, NULL, NULL FROM pg_indexes WHERE schemaname = 'public' AND tablename LIKE '%weight%'
    UNION ALL
    SELECT NULL, NULL, viewname, NULL FROM pg_views WHERE schemaname = 'public' AND viewname LIKE '%weight%'
    UNION ALL
    SELECT NULL, NULL, NULL, routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name LIKE '%weight%'
) summary_data;

-- 13. CHECK FOR POTENTIAL CONFLICTS
SELECT 
    'Potential Conflicts' as check_category,
    'animals table' as dependency,
    CASE 
        WHEN COUNT(*) > 0 THEN '✓ EXISTS (dependency satisfied)'
        ELSE '✗ MISSING (migration will fail)'
    END as status
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'animals';

-- 14. FINAL STATUS
SELECT 
    CASE 
        WHEN (
            SELECT COUNT(*) FROM pg_tables 
            WHERE schemaname = 'public' 
            AND tablename IN ('weights', 'weight_goals', 'weight_audit_log', 'weight_statistics_cache')
        ) = 4 THEN '✅ DEPLOYMENT SUCCESSFUL - All 4 tables created'
        ELSE '❌ DEPLOYMENT INCOMPLETE - Missing tables'
    END as final_status;