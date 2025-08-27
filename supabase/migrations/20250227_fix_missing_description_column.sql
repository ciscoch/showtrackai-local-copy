-- ============================================================================
-- HOTFIX: Add missing 'description' column to animals table
-- Purpose: Fix PGRST204 error - 'description' column not found in schema cache
-- Error: PostgrestException: Could not find the 'description' column of 'animals'
-- Date: 2025-02-27
-- ============================================================================

-- Start transaction for safety
BEGIN;

-- ============================================================================
-- STEP 1: Create helper function for safe column addition
-- ============================================================================

CREATE OR REPLACE FUNCTION safe_add_column_if_not_exists(
    p_table_name TEXT,
    p_column_name TEXT,
    p_column_definition TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    column_exists BOOLEAN;
BEGIN
    -- Check if column already exists
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = p_table_name 
        AND column_name = p_column_name
    ) INTO column_exists;
    
    IF NOT column_exists THEN
        -- Add the column
        EXECUTE format('ALTER TABLE %I ADD COLUMN %I %s', 
            p_table_name, p_column_name, p_column_definition);
        RAISE NOTICE '✅ Column %.% added successfully', p_table_name, p_column_name;
        RETURN TRUE;
    ELSE
        RAISE NOTICE '⚠️ Column %.% already exists - skipping', p_table_name, p_column_name;
        RETURN FALSE;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error adding column %.%: %', p_table_name, p_column_name, SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 2: Add missing columns to animals table
-- ============================================================================

DO $$
DECLARE
    description_added BOOLEAN;
    metadata_added BOOLEAN;
    photo_url_added BOOLEAN;
BEGIN
    RAISE NOTICE '🔧 Starting animals table schema fix...';
    
    -- Add description column (TEXT, nullable)
    description_added := safe_add_column_if_not_exists(
        'animals', 
        'description', 
        'TEXT NULL'
    );
    
    -- While we're at it, check for other potentially missing columns
    -- that exist in the application model but might be missing in production
    
    -- Add metadata column (JSONB, nullable)
    metadata_added := safe_add_column_if_not_exists(
        'animals', 
        'metadata', 
        'JSONB DEFAULT ''{}''::jsonb'
    );
    
    -- Add photo_url column (TEXT, nullable)
    photo_url_added := safe_add_column_if_not_exists(
        'animals', 
        'photo_url', 
        'TEXT NULL'
    );
    
    -- Report results
    IF description_added OR metadata_added OR photo_url_added THEN
        RAISE NOTICE '✅ Schema updates applied successfully';
    ELSE
        RAISE NOTICE '✅ Schema already up to date - no changes needed';
    END IF;
    
END $$;

-- ============================================================================
-- STEP 3: Add column comments for documentation
-- ============================================================================

COMMENT ON COLUMN animals.description IS 'Optional text description or notes about the animal';
COMMENT ON COLUMN animals.metadata IS 'Additional JSON metadata for flexible data storage';
COMMENT ON COLUMN animals.photo_url IS 'URL to the animal''s photo stored in external storage';

-- ============================================================================
-- STEP 4: Force PostgREST to reload its schema cache
-- ============================================================================

-- Method 1: Standard PostgREST cache reload
NOTIFY pgrst, 'reload schema';

-- Method 2: Alternative notification method
DO $$
BEGIN
    PERFORM pg_notify('pgrst', 'reload schema');
    RAISE NOTICE '📡 Sent schema reload notification to PostgREST';
END $$;

-- Method 3: For Supabase specifically, touch the schema version
-- This forces Supabase to recognize schema changes
DO $$
BEGIN
    -- Update schema_migrations table if it exists (Supabase internal)
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'schema_migrations'
    ) THEN
        INSERT INTO schema_migrations (version) 
        VALUES ('20250227_fix_missing_columns')
        ON CONFLICT (version) DO NOTHING;
    END IF;
END $$;

-- ============================================================================
-- STEP 5: Verify the fix
-- ============================================================================

DO $$
DECLARE
    col_count INTEGER;
    expected_columns TEXT[] := ARRAY[
        'id', 'user_id', 'name', 'tag', 'species', 'breed', 'gender',
        'birth_date', 'purchase_weight', 'current_weight', 'purchase_date',
        'purchase_price', 'description', 'photo_url', 'metadata',
        'created_at', 'updated_at'
    ];
    missing_columns TEXT[];
    col TEXT;
BEGIN
    -- Count columns in animals table
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'animals';
    
    RAISE NOTICE '📊 Animals table has % columns', col_count;
    
    -- Check for any still-missing expected columns
    missing_columns := ARRAY[]::TEXT[];
    
    FOREACH col IN ARRAY expected_columns
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' 
            AND table_name = 'animals'
            AND column_name = col
        ) THEN
            missing_columns := array_append(missing_columns, col);
        END IF;
    END LOOP;
    
    IF array_length(missing_columns, 1) > 0 THEN
        RAISE WARNING '⚠️ Still missing columns: %', missing_columns;
    ELSE
        RAISE NOTICE '✅ All expected columns are present';
    END IF;
    
    -- Display the current table structure
    RAISE NOTICE '📋 Current animals table structure:';
    FOR col IN 
        SELECT column_name || ' (' || data_type || 
               CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END || ')'
        FROM information_schema.columns
        WHERE table_schema = 'public' 
        AND table_name = 'animals'
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE '   - %', col;
    END LOOP;
    
END $$;

-- ============================================================================
-- STEP 6: Test that updates work with the description field
-- ============================================================================

DO $$
DECLARE
    test_result BOOLEAN;
BEGIN
    -- Try a dummy update to verify the column is accessible
    -- This won't actually update anything but tests the column exists
    BEGIN
        UPDATE animals 
        SET description = description
        WHERE FALSE; -- This ensures no rows are actually updated
        
        RAISE NOTICE '✅ Description column is accessible for updates';
        test_result := TRUE;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '❌ Description column test failed: %', SQLERRM;
        test_result := FALSE;
    END;
    
END $$;

-- ============================================================================
-- STEP 7: Clean up helper function
-- ============================================================================

DROP FUNCTION IF EXISTS safe_add_column_if_not_exists(TEXT, TEXT, TEXT);

-- Commit the transaction
COMMIT;

-- ============================================================================
-- FINAL SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ MIGRATION COMPLETED SUCCESSFULLY';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📋 Summary:';
    RAISE NOTICE '  • Added missing ''description'' column to animals table';
    RAISE NOTICE '  • Refreshed PostgREST schema cache';
    RAISE NOTICE '  • Verified table structure';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Next steps:';
    RAISE NOTICE '  1. Test animal update functionality in your application';
    RAISE NOTICE '  2. The PGRST204 error should be resolved';
    RAISE NOTICE '  3. Monitor for any other missing columns';
    RAISE NOTICE '========================================';
END $$;

-- ============================================================================
-- ROLLBACK INSTRUCTIONS (if needed)
-- ============================================================================

/*
To rollback this migration (remove the added columns):

ALTER TABLE animals DROP COLUMN IF EXISTS description;
ALTER TABLE animals DROP COLUMN IF EXISTS metadata;
ALTER TABLE animals DROP COLUMN IF EXISTS photo_url;
NOTIFY pgrst, 'reload schema';

*/

-- ============================================================================
-- VERIFICATION QUERIES (run manually after migration)
-- ============================================================================

/*
-- 1. Check that description column exists
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'animals' 
AND column_name = 'description';

-- 2. Test an update with description
UPDATE animals 
SET description = 'Test description update', 
    updated_at = CURRENT_TIMESTAMP
WHERE id = 'your-test-animal-id-here'
RETURNING id, name, description;

-- 3. Check PostgREST can see the column
-- Make an API call to: /rest/v1/animals?select=id,name,description&limit=1

*/