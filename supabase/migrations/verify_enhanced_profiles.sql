-- ============================================================================
-- VERIFICATION SCRIPT FOR ENHANCED USER PROFILES MIGRATION
-- ============================================================================
-- Run this after completing all migration parts to verify everything worked

-- 1. Check new columns in user_profiles
SELECT 
    'User Profile Columns' as check_name,
    COUNT(*) as columns_added,
    array_agg(column_name ORDER BY column_name) as new_columns
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND column_name IN ('bio', 'phone', 'ffa_chapter', 'ffa_degree', 'ffa_state', 
                    'member_since', 'profile_image_url', 'address', 'emergency_contact',
                    'educational_info', 'preferences', 'social_links', 'achievements', 
                    'skills_certifications');

-- 2. Check all new tables exist
SELECT 
    'New Tables' as check_name,
    COUNT(*) as tables_created,
    array_agg(table_name ORDER BY table_name) as table_list
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills');

-- 3. Check sample data was inserted
SELECT 
    'Sample Data' as check_name,
    jsonb_build_object(
        'ffa_degrees', (SELECT COUNT(*) FROM ffa_degrees),
        'ffa_chapters', (SELECT COUNT(*) FROM ffa_chapters),
        'skills_catalog', (SELECT COUNT(*) FROM skills_catalog)
    ) as data_counts;

-- 4. Check RLS is enabled
SELECT 
    'RLS Status' as check_name,
    COUNT(*) as tables_with_rls,
    array_agg(tablename ORDER BY tablename) as tables
FROM pg_tables 
WHERE schemaname = 'public' 
AND rowsecurity = true
AND tablename IN ('ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills');

-- 5. Check RLS policies exist
SELECT 
    'RLS Policies' as check_name,
    tablename,
    COUNT(*) as policy_count,
    array_agg(policyname ORDER BY policyname) as policies
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills')
GROUP BY tablename
ORDER BY tablename;

-- 6. Check indexes were created
SELECT 
    'Indexes' as check_name,
    COUNT(*) as index_count,
    array_agg(indexname ORDER BY indexname) as index_list
FROM pg_indexes 
WHERE schemaname = 'public' 
AND tablename IN ('user_profiles', 'ffa_chapters', 'user_ffa_progress', 'skills_catalog', 'user_skills')
AND indexname LIKE 'idx_%';

-- 7. Check functions exist
SELECT 
    'Functions' as check_name,
    COUNT(*) as function_count,
    array_agg(proname ORDER BY proname) as function_list
FROM pg_proc 
WHERE proname IN ('validate_phone', 'validate_state_code', 'calculate_profile_completion', 'get_ffa_degree_progress')
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- 8. Check views exist
SELECT 
    'Views' as check_name,
    COUNT(*) as view_count,
    array_agg(table_name ORDER BY table_name) as view_list
FROM information_schema.views 
WHERE table_schema = 'public' 
AND table_name IN ('user_profile_summary', 'ffa_degree_progress_view');

-- 9. Test profile completion function (if any users exist)
SELECT 
    'Profile Completion Test' as check_name,
    CASE 
        WHEN COUNT(*) = 0 THEN 'No users to test'
        ELSE 'Function works - tested on ' || COUNT(*) || ' users'
    END as result
FROM (
    SELECT calculate_profile_completion(id) 
    FROM user_profiles 
    LIMIT 5
) test;

-- 10. Final summary
SELECT 
    'MIGRATION SUMMARY' as status,
    CASE 
        WHEN (
            SELECT COUNT(*) FROM information_schema.columns 
            WHERE table_name = 'user_profiles' AND column_name = 'bio'
        ) > 0 
        AND (
            SELECT COUNT(*) FROM information_schema.tables 
            WHERE table_name = 'ffa_chapters'
        ) > 0
        AND (
            SELECT COUNT(*) FROM ffa_degrees
        ) > 0
        THEN '✅ SUCCESS - Migration completed successfully!'
        ELSE '⚠️  INCOMPLETE - Some components may be missing'
    END as result,
    NOW() as checked_at;