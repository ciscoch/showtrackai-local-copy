-- ============================================================================
-- AI Assessment Schema Verification Script
-- Run this to verify the journal_entry_ai_assessments infrastructure
-- ============================================================================

-- 1. Verify table exists and has correct structure
DO $$
DECLARE
    table_exists BOOLEAN;
    column_count INTEGER;
    index_count INTEGER;
    policy_count INTEGER;
    function_count INTEGER;
BEGIN
    -- Check table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'journal_entry_ai_assessments'
    ) INTO table_exists;
    
    IF NOT table_exists THEN
        RAISE EXCEPTION 'journal_entry_ai_assessments table does NOT exist! Run the migration first.';
    END IF;
    
    -- Count columns
    SELECT COUNT(*) INTO column_count
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'journal_entry_ai_assessments';
    
    -- Count indexes
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes 
    WHERE tablename = 'journal_entry_ai_assessments';
    
    -- Count policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename = 'journal_entry_ai_assessments';
    
    -- Count functions
    SELECT COUNT(*) INTO function_count
    FROM information_schema.routines
    WHERE routine_schema = 'public' 
    AND routine_name IN ('upsert_ai_assessment', 'get_ai_assessment_for_journal_entry', 'get_student_ai_competency_progress');
    
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'AI Assessment Schema Verification Results:';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ Table exists: journal_entry_ai_assessments';
    RAISE NOTICE '📊 Columns: % (expected: 25)', column_count;
    RAISE NOTICE '🚀 Indexes: % (expected: 8+)', index_count;
    RAISE NOTICE '🔒 RLS Policies: % (expected: 2)', policy_count;
    RAISE NOTICE '⚙️  Functions: % (expected: 3)', function_count;
    
    IF column_count >= 25 AND index_count >= 8 AND policy_count >= 2 AND function_count >= 3 THEN
        RAISE NOTICE '✅ All components verified successfully!';
    ELSE
        RAISE NOTICE '⚠️  Some components may be missing. Check migration.';
    END IF;
    
    RAISE NOTICE '===========================================';
END;
$$;

-- 2. Test the upsert function with sample data
SELECT 'Testing upsert_ai_assessment function...' as test_step;

DO $$
DECLARE
    test_journal_id UUID := 'f47ac10b-58cc-4372-a567-0e02b2c3d479';  -- Fake UUID for testing
    test_assessment_data JSONB;
    assessment_id UUID;
BEGIN
    -- Create test assessment data
    test_assessment_data := '{
        "assessment_type": "journal_analysis",
        "quality_score": 8.5,
        "engagement_score": 7.8,
        "learning_depth_score": 8.0,
        "competencies_identified": ["AS.01.01", "AS.02.03"],
        "ffa_standards_matched": ["CRP.02", "CRP.04"],
        "strengths_identified": ["Strong technical knowledge", "Good observation skills"],
        "growth_areas": ["Needs more reflection", "Include more evidence"],
        "recommendations": ["Add photos next time", "Include measurements"],
        "confidence_score": 0.85,
        "model_used": "gpt-4"
    }';
    
    -- This will likely fail because test_journal_id doesn't exist, but it tests function syntax
    BEGIN
        SELECT upsert_ai_assessment(
            test_journal_id,
            test_assessment_data,
            'test_n8n_run_123',
            gen_random_uuid()
        ) INTO assessment_id;
        
        RAISE NOTICE '✅ upsert_ai_assessment function works! Assessment ID: %', assessment_id;
        
        -- Clean up test data
        DELETE FROM journal_entry_ai_assessments WHERE id = assessment_id;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '⚠️  upsert_ai_assessment test failed (expected if no test journal entry): %', SQLERRM;
    END;
END;
$$;

-- 3. Verify the analytics views exist
SELECT 'Testing analytics views...' as test_step;

DO $$
DECLARE
    view_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_schema = 'public' AND table_name = 'journal_ai_assessment_summary'
    ) INTO view_exists;
    
    IF view_exists THEN
        RAISE NOTICE '✅ journal_ai_assessment_summary view exists';
    ELSE
        RAISE NOTICE '❌ journal_ai_assessment_summary view missing';
    END IF;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_schema = 'public' AND table_name = 'ai_competency_progress'
    ) INTO view_exists;
    
    IF view_exists THEN
        RAISE NOTICE '✅ ai_competency_progress view exists';
    ELSE
        RAISE NOTICE '❌ ai_competency_progress view missing';
    END IF;
END;
$$;

-- 4. Check RLS is enabled
SELECT 
    CASE WHEN rowsecurity THEN 
        '✅ RLS enabled on journal_entry_ai_assessments'
    ELSE 
        '❌ RLS NOT enabled on journal_entry_ai_assessments' 
    END as rls_status
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'journal_entry_ai_assessments';

-- 5. Show current policies
SELECT 
    '📋 Current RLS Policies:' as policies_header
UNION ALL
SELECT 
    '  - ' || policyname || ' (' || cmd || ')'
FROM pg_policies 
WHERE tablename = 'journal_entry_ai_assessments'
ORDER BY policyname;

-- 6. Final verification summary
SELECT 
    '===========================================
🎯 VERIFICATION COMPLETE
===========================================
If you see ✅ for all components above, your AI assessment 
storage system is ready for production!

If you see any ❌ or ⚠️  messages, run the migration:
supabase db push

Then deploy the Edge Function:
./deploy-spar-callback.sh

N8N webhook should call:
https://[PROJECT].supabase.co/functions/v1/spar-callback
===========================================' as summary;