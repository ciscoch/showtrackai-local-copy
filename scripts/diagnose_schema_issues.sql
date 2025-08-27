-- ============================================================================
-- QUICK DIAGNOSIS: Check what columns are missing from animals table
-- Run this FIRST to see the current state before applying migrations
-- ============================================================================

-- Show current columns
SELECT '📊 CURRENT ANIMALS TABLE COLUMNS:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'animals'
ORDER BY ordinal_position;

-- Check for specific missing columns
SELECT '';
SELECT '🔍 CHECKING FOR CRITICAL COLUMNS:' as info;
WITH expected_columns AS (
    SELECT unnest(ARRAY[
        'id', 'user_id', 'name', 'tag', 'species', 'breed', 'gender',
        'birth_date', 'purchase_weight', 'current_weight', 'purchase_date',
        'purchase_price', 'description', 'photo_url', 'metadata',
        'created_at', 'updated_at'
    ]) AS column_name
),
actual_columns AS (
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'animals'
)
SELECT 
    e.column_name,
    CASE 
        WHEN a.column_name IS NOT NULL THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END AS status
FROM expected_columns e
LEFT JOIN actual_columns a ON e.column_name = a.column_name
ORDER BY 
    CASE WHEN a.column_name IS NULL THEN 0 ELSE 1 END,
    e.column_name;

-- Count missing columns
SELECT '';
SELECT '📈 SUMMARY:' as info;
WITH expected_columns AS (
    SELECT unnest(ARRAY[
        'id', 'user_id', 'name', 'tag', 'species', 'breed', 'gender',
        'birth_date', 'purchase_weight', 'current_weight', 'purchase_date',
        'purchase_price', 'description', 'photo_url', 'metadata',
        'created_at', 'updated_at'
    ]) AS column_name
),
actual_columns AS (
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'animals'
)
SELECT 
    COUNT(DISTINCT e.column_name) as expected_columns,
    COUNT(DISTINCT a.column_name) as actual_columns,
    COUNT(DISTINCT e.column_name) - COUNT(DISTINCT CASE WHEN a.column_name IS NOT NULL THEN e.column_name END) as missing_columns
FROM expected_columns e
LEFT JOIN actual_columns a ON e.column_name = a.column_name;

-- Generate quick fix commands for missing columns
SELECT '';
SELECT '🔧 QUICK FIX COMMANDS (copy and run if needed):' as info;
WITH expected_columns AS (
    SELECT 
        column_name,
        CASE column_name
            WHEN 'id' THEN 'UUID DEFAULT gen_random_uuid() PRIMARY KEY'
            WHEN 'user_id' THEN 'UUID NOT NULL REFERENCES auth.users(id)'
            WHEN 'name' THEN 'VARCHAR(255) NOT NULL'
            WHEN 'tag' THEN 'VARCHAR(100)'
            WHEN 'species' THEN 'VARCHAR(50) NOT NULL'
            WHEN 'breed' THEN 'VARCHAR(100)'
            WHEN 'gender' THEN 'VARCHAR(50)'
            WHEN 'birth_date' THEN 'DATE'
            WHEN 'purchase_weight' THEN 'DECIMAL(10,2)'
            WHEN 'current_weight' THEN 'DECIMAL(10,2)'
            WHEN 'purchase_date' THEN 'DATE'
            WHEN 'purchase_price' THEN 'DECIMAL(10,2)'
            WHEN 'description' THEN 'TEXT'
            WHEN 'photo_url' THEN 'TEXT'
            WHEN 'metadata' THEN 'JSONB DEFAULT ''{}''::jsonb'
            WHEN 'created_at' THEN 'TIMESTAMP WITH TIME ZONE DEFAULT NOW()'
            WHEN 'updated_at' THEN 'TIMESTAMP WITH TIME ZONE DEFAULT NOW()'
        END AS column_definition
    FROM (
        SELECT unnest(ARRAY[
            'id', 'user_id', 'name', 'tag', 'species', 'breed', 'gender',
            'birth_date', 'purchase_weight', 'current_weight', 'purchase_date',
            'purchase_price', 'description', 'photo_url', 'metadata',
            'created_at', 'updated_at'
        ]) AS column_name
    ) cols
),
actual_columns AS (
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'animals'
)
SELECT 
    'ALTER TABLE animals ADD COLUMN IF NOT EXISTS ' || 
    e.column_name || ' ' || e.column_definition || ';' AS fix_command
FROM expected_columns e
LEFT JOIN actual_columns a ON e.column_name = a.column_name
WHERE a.column_name IS NULL;

-- Force PostgREST cache refresh
SELECT '';
SELECT '📡 DON''T FORGET TO REFRESH POSTGREST CACHE:' as info;
SELECT 'NOTIFY pgrst, ''reload schema'';' as command;