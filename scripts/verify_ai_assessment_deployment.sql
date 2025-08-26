-- ============================================================================
-- AI Assessment Integration Deployment Verification Script
-- ============================================================================
-- Run this script after deploying the AI assessment integration to verify
-- that all components are working correctly.

-- Enable expanded output for better readability
\x on

-- ============================================================================
-- 1. VERIFY TABLE STRUCTURE
-- ============================================================================

\echo '===================================================='
\echo 'VERIFYING AI ASSESSMENT TABLE STRUCTURE'
\echo '===================================================='

-- Check if the table exists
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'journal_entry_ai_assessments'
        ) 
        THEN '✅ journal_entry_ai_assessments table exists'
        ELSE '❌ journal_entry_ai_assessments table NOT found'
    END as table_status;

-- Check table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'journal_entry_ai_assessments'
ORDER BY ordinal_position;

-- ============================================================================
-- 2. VERIFY INDEXES
-- ============================================================================

\echo '===================================================='
\echo 'VERIFYING AI ASSESSMENT INDEXES'
\echo '===================================================='

SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public' 
AND tablename = 'journal_entry_ai_assessments'
ORDER BY indexname;

-- ============================================================================
-- 3. VERIFY RLS POLICIES
-- ============================================================================

\echo '===================================================='
\echo 'VERIFYING ROW LEVEL SECURITY POLICIES'
\echo '===================================================='

-- Check if RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'journal_entry_ai_assessments';

-- List all policies
SELECT 
    policyname,
    cmd,
    permissive,
    roles,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'journal_entry_ai_assessments'
ORDER BY policyname;

-- ============================================================================
-- 4. VERIFY DATABASE FUNCTIONS
-- ============================================================================

\echo '===================================================='
\echo 'VERIFYING DATABASE FUNCTIONS'
\echo '===================================================='

-- Check if required functions exist
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public' 
AND routine_name IN (
    'upsert_ai_assessment',
    'get_ai_assessment_for_journal_entry', 
    'get_student_ai_competency_progress'
)
ORDER BY routine_name;

-- Test upsert_ai_assessment function signature
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'upsert_ai_assessment';

-- ============================================================================
-- 5. VERIFY VIEWS
-- ============================================================================

\echo '===================================================='
\echo 'VERIFYING ANALYTICS VIEWS'
\echo '===================================================='

-- Check if views exist
SELECT 
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public' 
AND table_name IN (
    'journal_ai_assessment_summary',
    'ai_competency_progress'
)
ORDER BY table_name;

-- Test view structure
SELECT 
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'journal_ai_assessment_summary'
ORDER BY ordinal_position;

-- ============================================================================
-- 6. VERIFY TRIGGERS
-- ============================================================================

\echo '===================================================='
\echo 'VERIFYING TRIGGERS'
\echo '===================================================='

-- List triggers on the AI assessment table
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'public'
AND event_object_table = 'journal_entry_ai_assessments'
ORDER BY trigger_name;

-- ============================================================================
-- 7. TEST BASIC FUNCTIONALITY
-- ============================================================================

\echo '===================================================='
\echo 'TESTING BASIC FUNCTIONALITY'
\echo '===================================================='

-- Test inserting a sample assessment (will be cleaned up)
BEGIN;

-- Create a test journal entry if needed
INSERT INTO journal_entries (id, user_id, title, content, category)
SELECT 
    'test-journal-ai-assessment',
    auth.uid(),
    'Test Journal for AI Assessment',
    'This is a test journal entry for AI assessment verification.',
    'testing'
WHERE NOT EXISTS (
    SELECT 1 FROM journal_entries 
    WHERE id = 'test-journal-ai-assessment'
);

-- Test the upsert function
SELECT upsert_ai_assessment(
    'test-journal-ai-assessment',
    '{
        "assessment_type": "journal_analysis",
        "quality_score": 8.5,
        "engagement_score": 7.8,
        "competencies_identified": ["AS.07.01", "AS.07.02"],
        "ffa_standards_matched": ["Animal Health Management"],
        "strengths_identified": ["Good documentation"],
        "growth_areas": ["Include costs"],
        "recommendations": ["Continue monitoring"],
        "confidence_score": 0.89,
        "model_used": "gpt-4-test"
    }'::jsonb,
    'test-run-123',
    'test-trace-456'
) as test_assessment_id;

-- Verify the assessment was inserted
SELECT 
    id,
    journal_entry_id,
    quality_score,
    jsonb_array_length(competencies_identified) as competency_count,
    n8n_run_id,
    trace_id,
    created_at
FROM journal_entry_ai_assessments
WHERE n8n_run_id = 'test-run-123';

-- Test the get function
SELECT * FROM get_ai_assessment_for_journal_entry(
    'test-journal-ai-assessment',
    'journal_analysis'
);

-- Test the view
SELECT 
    journal_entry_id,
    quality_score,
    competencies_count,
    assessment_date
FROM journal_ai_assessment_summary
WHERE journal_entry_id = 'test-journal-ai-assessment';

-- Clean up test data
ROLLBACK;

-- ============================================================================
-- 8. VERIFY SPAR INTEGRATION
-- ============================================================================

\echo '===================================================='
\echo 'VERIFYING SPAR RUNS TABLE INTEGRATION'
\echo '===================================================='

-- Check if spar_runs table exists and has necessary columns
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'spar_runs'
        ) 
        THEN '✅ spar_runs table exists'
        ELSE '❌ spar_runs table NOT found'
    END as spar_table_status;

-- Check for journal_entry_id column in spar_runs
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'spar_runs'
AND column_name IN ('journal_entry_id', 'trace_id', 'run_id')
ORDER BY column_name;

-- ============================================================================
-- 9. VERIFY EDGE FUNCTION PERMISSIONS
-- ============================================================================

\echo '===================================================='
\echo 'VERIFYING PERMISSIONS'
\echo '===================================================='

-- Check function permissions
SELECT 
    p.proname as function_name,
    r.rolname as granted_to,
    'EXECUTE' as permission_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
JOIN pg_depend d ON d.objid = p.oid
JOIN pg_authid r ON d.refobjid = r.oid
WHERE n.nspname = 'public' 
AND p.proname IN (
    'upsert_ai_assessment',
    'get_ai_assessment_for_journal_entry'
)
UNION
-- Check table permissions
SELECT 
    t.table_name,
    grantee,
    privilege_type
FROM information_schema.table_privileges t
WHERE t.table_schema = 'public'
AND t.table_name = 'journal_entry_ai_assessments'
ORDER BY function_name, granted_to;

-- ============================================================================
-- 10. PERFORMANCE VERIFICATION
-- ============================================================================

\echo '===================================================='
\echo 'PERFORMANCE AND OPTIMIZATION VERIFICATION'
\echo '===================================================='

-- Check for essential indexes
WITH required_indexes AS (
    SELECT unnest(ARRAY[
        'journal_entry_ai_assessments_pkey',
        'idx_ai_assessments_journal_entry',
        'idx_ai_assessments_quality_score',
        'idx_ai_assessments_competencies',
        'idx_ai_assessments_trace_id'
    ]) as index_name
)
SELECT 
    ri.index_name,
    CASE 
        WHEN pi.indexname IS NOT NULL THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status
FROM required_indexes ri
LEFT JOIN pg_indexes pi ON pi.indexname = ri.index_name 
    AND pi.schemaname = 'public'
    AND pi.tablename = 'journal_entry_ai_assessments'
ORDER BY ri.index_name;

-- Check constraint violations
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    CASE contype
        WHEN 'c' THEN 'CHECK'
        WHEN 'f' THEN 'FOREIGN KEY'  
        WHEN 'p' THEN 'PRIMARY KEY'
        WHEN 'u' THEN 'UNIQUE'
        ELSE contype::text
    END as constraint_description
FROM pg_constraint
WHERE conrelid = 'public.journal_entry_ai_assessments'::regclass
ORDER BY conname;

-- ============================================================================
-- 11. DEPLOYMENT SUMMARY
-- ============================================================================

\echo '===================================================='
\echo 'DEPLOYMENT VERIFICATION SUMMARY'
\echo '===================================================='

WITH verification_summary AS (
    SELECT 
        'Table Structure' as component,
        CASE WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'journal_entry_ai_assessments'
        ) THEN '✅ PASS' ELSE '❌ FAIL' END as status
    
    UNION ALL
    
    SELECT 
        'RLS Policies' as component,
        CASE WHEN (
            SELECT COUNT(*) FROM pg_policies 
            WHERE schemaname = 'public' 
            AND tablename = 'journal_entry_ai_assessments'
        ) >= 2 THEN '✅ PASS' ELSE '❌ FAIL' END as status
    
    UNION ALL
    
    SELECT 
        'Database Functions' as component,
        CASE WHEN (
            SELECT COUNT(*) FROM information_schema.routines
            WHERE routine_schema = 'public' 
            AND routine_name IN (
                'upsert_ai_assessment',
                'get_ai_assessment_for_journal_entry',
                'get_student_ai_competency_progress'
            )
        ) = 3 THEN '✅ PASS' ELSE '❌ FAIL' END as status
    
    UNION ALL
    
    SELECT 
        'Analytics Views' as component,
        CASE WHEN (
            SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = 'public' 
            AND table_name IN (
                'journal_ai_assessment_summary',
                'ai_competency_progress'
            )
        ) = 2 THEN '✅ PASS' ELSE '❌ FAIL' END as status
    
    UNION ALL
    
    SELECT 
        'Essential Indexes' as component,
        CASE WHEN (
            SELECT COUNT(*) FROM pg_indexes 
            WHERE schemaname = 'public' 
            AND tablename = 'journal_entry_ai_assessments'
        ) >= 5 THEN '✅ PASS' ELSE '❌ FAIL' END as status
    
    UNION ALL
    
    SELECT 
        'Triggers' as component,
        CASE WHEN (
            SELECT COUNT(*) FROM information_schema.triggers
            WHERE event_object_schema = 'public'
            AND event_object_table = 'journal_entry_ai_assessments'
        ) >= 2 THEN '✅ PASS' ELSE '❌ FAIL' END as status
)
SELECT 
    component,
    status
FROM verification_summary
ORDER BY component;

-- Final status check
SELECT 
    CASE 
        WHEN (
            SELECT COUNT(*) FROM (
                SELECT 
                    CASE WHEN EXISTS (
                        SELECT 1 FROM information_schema.tables 
                        WHERE table_schema = 'public' 
                        AND table_name = 'journal_entry_ai_assessments'
                    ) THEN 1 ELSE 0 END +
                    CASE WHEN (
                        SELECT COUNT(*) FROM pg_policies 
                        WHERE schemaname = 'public' 
                        AND tablename = 'journal_entry_ai_assessments'
                    ) >= 2 THEN 1 ELSE 0 END +
                    CASE WHEN (
                        SELECT COUNT(*) FROM information_schema.routines
                        WHERE routine_schema = 'public' 
                        AND routine_name IN (
                            'upsert_ai_assessment',
                            'get_ai_assessment_for_journal_entry',
                            'get_student_ai_competency_progress'
                        )
                    ) = 3 THEN 1 ELSE 0 END +
                    CASE WHEN (
                        SELECT COUNT(*) FROM information_schema.tables
                        WHERE table_schema = 'public' 
                        AND table_name IN (
                            'journal_ai_assessment_summary',
                            'ai_competency_progress'
                        )
                    ) = 2 THEN 1 ELSE 0 END as total_score
            ) t
        ) = 4
        THEN '🎉 AI ASSESSMENT INTEGRATION DEPLOYMENT SUCCESSFUL! All components verified.'
        ELSE '⚠️  AI ASSESSMENT INTEGRATION DEPLOYMENT INCOMPLETE. Some components missing or failed verification.'
    END as deployment_status;

\echo '===================================================='
\echo 'VERIFICATION COMPLETE'
\echo '===================================================='
\echo 'If all components show ✅ PASS, your AI Assessment integration is ready!'
\echo 'If any components show ❌ FAIL, review the migration scripts and re-run.'
\echo '===================================================='

-- Turn off expanded output
\x off