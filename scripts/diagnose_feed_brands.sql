-- =============================================
-- FEED BRANDS DIAGNOSTIC SCRIPT
-- =============================================
-- Run this script in Supabase SQL Editor to diagnose feed brands issues
-- =============================================

-- 1. Check if tables exist
SELECT 
    'Table Existence Check' as diagnostic_step,
    table_name,
    CASE 
        WHEN table_name IS NOT NULL THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('feed_brands', 'feed_products', 'journal_feed_items', 'user_feed_recent')
ORDER BY table_name;

-- 2. Check feed_brands table structure
SELECT 
    'Feed Brands Structure' as diagnostic_step,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'feed_brands'
ORDER BY ordinal_position;

-- 3. Check RLS status
SELECT 
    'RLS Status' as diagnostic_step,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('feed_brands', 'feed_products')
ORDER BY tablename;

-- 4. Check RLS policies
SELECT 
    'RLS Policies' as diagnostic_step,
    tablename,
    policyname,
    cmd as operation,
    permissive,
    roles
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('feed_brands', 'feed_products')
ORDER BY tablename, policyname;

-- 5. Check data in feed_brands
SELECT 
    'Feed Brands Data Check' as diagnostic_step,
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE id IS NOT NULL) as records_with_id,
    COUNT(*) FILTER (WHERE name IS NOT NULL AND name != '') as records_with_name,
    COUNT(*) FILTER (WHERE is_active = true) as active_records,
    COUNT(*) FILTER (WHERE is_active IS NULL) as null_active_status
FROM feed_brands;

-- 6. Sample feed_brands data (first 5 records)
SELECT 
    'Sample Feed Brands' as diagnostic_step,
    id,
    name,
    is_active,
    created_at,
    CASE 
        WHEN id IS NULL THEN '❌ NULL ID'
        WHEN name IS NULL OR name = '' THEN '❌ NULL/EMPTY NAME'
        WHEN is_active IS NULL THEN '❌ NULL ACTIVE STATUS'
        ELSE '✅ OK'
    END as data_status
FROM feed_brands
LIMIT 5;

-- 7. Check for duplicate brand names
SELECT 
    'Duplicate Brand Names' as diagnostic_step,
    LOWER(TRIM(name)) as normalized_name,
    COUNT(*) as duplicate_count,
    STRING_AGG(id::text, ', ') as duplicate_ids
FROM feed_brands
WHERE name IS NOT NULL
GROUP BY LOWER(TRIM(name))
HAVING COUNT(*) > 1;

-- 8. Check feed_products count by brand
SELECT 
    'Products per Brand' as diagnostic_step,
    fb.name as brand_name,
    COUNT(fp.id) as product_count,
    fb.is_active as brand_active
FROM feed_brands fb
LEFT JOIN feed_products fp ON fb.id = fp.brand_id
GROUP BY fb.id, fb.name, fb.is_active
ORDER BY fb.name;

-- 9. Check authentication requirements
SELECT 
    'Authentication Check' as diagnostic_step,
    current_user,
    session_user,
    CASE 
        WHEN auth.uid() IS NULL THEN '❌ No authenticated user'
        ELSE '✅ User authenticated: ' || auth.uid()::text
    END as auth_status;

-- 10. Attempt to query feed_brands as authenticated user would
DO $$
DECLARE
    test_result RECORD;
    error_msg TEXT;
BEGIN
    BEGIN
        -- Try to select from feed_brands
        SELECT COUNT(*) as count INTO test_result
        FROM feed_brands
        WHERE is_active = true;
        
        RAISE NOTICE '✅ Query test passed. Found % active brands', test_result.count;
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS error_msg = MESSAGE_TEXT;
            RAISE NOTICE '❌ Query test failed: %', error_msg;
    END;
END;
$$;

-- 11. Final Summary
SELECT 
    '🔍 DIAGNOSTIC SUMMARY' as summary,
    (SELECT COUNT(*) FROM feed_brands) as total_brands,
    (SELECT COUNT(*) FROM feed_brands WHERE is_active = true) as active_brands,
    (SELECT COUNT(*) FROM feed_products) as total_products,
    (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'feed_brands') as rls_policies,
    CASE 
        WHEN (SELECT COUNT(*) FROM feed_brands WHERE is_active = true) >= 10 THEN '✅ Data looks good'
        WHEN (SELECT COUNT(*) FROM feed_brands) = 0 THEN '❌ No brands found - migration may have failed'
        WHEN (SELECT COUNT(*) FROM feed_brands WHERE is_active = true) = 0 THEN '❌ No active brands'
        ELSE '⚠️ Insufficient active brands'
    END as diagnosis;