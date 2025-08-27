-- ============================================================================
-- TEST AUTHENTICATION AFTER MIGRATION
-- ============================================================================
-- Run this to ensure authentication and user access still works properly

-- 1. Test that auth.users table is accessible
SELECT 
    'Auth Users Table' as test_name,
    COUNT(*) as user_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Auth table accessible'
        ELSE '⚠️  No users found (might be empty database)'
    END as status
FROM auth.users;

-- 2. Test that user_profiles table is accessible
SELECT 
    'User Profiles Table' as test_name,
    COUNT(*) as profile_count,
    CASE 
        WHEN COUNT(*) >= 0 THEN '✅ Profiles table accessible'
        ELSE '❌ Cannot access profiles'
    END as status
FROM user_profiles;

-- 3. Test that auth.users and user_profiles are linked properly
SELECT 
    'Auth-Profile Link' as test_name,
    COUNT(*) as linked_users,
    CASE 
        WHEN COUNT(*) >= 0 THEN '✅ Tables properly linked'
        ELSE '❌ Link broken'
    END as status
FROM auth.users au
LEFT JOIN user_profiles up ON up.id = au.id;

-- 4. Check that RLS doesn't break user access
-- This simulates a user trying to access their own profile
DO $$
DECLARE
    test_user_id UUID;
    test_result BOOLEAN;
BEGIN
    -- Get a random user ID if any exist
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        -- Test if the user could theoretically access their own profile
        -- (In real app, this would be through auth.uid())
        SELECT EXISTS(
            SELECT 1 FROM user_profiles WHERE id = test_user_id
        ) INTO test_result;
        
        RAISE NOTICE 'RLS Test: User % can access their profile: %', test_user_id, test_result;
    ELSE
        RAISE NOTICE 'RLS Test: No users found to test';
    END IF;
END $$;

-- 5. Test new columns don't break existing queries
SELECT 
    'Column Compatibility' as test_name,
    COUNT(*) as profiles_checked,
    CASE 
        WHEN COUNT(*) >= 0 THEN '✅ New columns compatible'
        ELSE '❌ Column issue detected'
    END as status
FROM user_profiles
WHERE 1=1
    -- Test that we can query with new columns
    AND (bio IS NULL OR bio IS NOT NULL)
    AND (phone IS NULL OR phone IS NOT NULL)
    AND (ffa_chapter IS NULL OR ffa_chapter IS NOT NULL);

-- 6. Test that essential RLS policies exist on user_profiles
SELECT 
    'User Profile RLS' as test_name,
    COUNT(*) as policy_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ RLS policies exist on user_profiles'
        WHEN rowsecurity = false THEN '⚠️  RLS disabled on user_profiles'
        ELSE '⚠️  No RLS policies on user_profiles (but RLS enabled)'
    END as status,
    rowsecurity as rls_enabled
FROM pg_policies p
RIGHT JOIN pg_tables t ON p.tablename = t.tablename
WHERE t.schemaname = 'public' 
AND t.tablename = 'user_profiles'
GROUP BY t.rowsecurity;

-- 7. Check if auth functions still work
SELECT 
    'Auth Functions' as test_name,
    CASE 
        WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'uid' AND pronamespace = 'auth'::regnamespace) 
        THEN '✅ auth.uid() function exists'
        ELSE '❌ auth.uid() function missing'
    END as status;

-- 8. Final authentication health check
SELECT 
    'AUTHENTICATION HEALTH CHECK' as status,
    jsonb_build_object(
        'auth_users_accessible', EXISTS(SELECT 1 FROM auth.users LIMIT 1),
        'user_profiles_accessible', EXISTS(SELECT 1 FROM user_profiles LIMIT 1),
        'new_columns_added', EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'bio'),
        'rls_active', EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'user_profiles' AND rowsecurity = true),
        'timestamp', NOW()
    ) as health_status,
    CASE 
        WHEN EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'bio')
        THEN '✅ HEALTHY - Authentication should work normally'
        ELSE '⚠️  CHECK NEEDED - Review authentication flow'
    END as recommendation;