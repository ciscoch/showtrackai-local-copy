-- Migration: Add missing 'description' column to animals table
-- Date: 2025-01-27
-- Purpose: Fix production error where application expects 'description' column that doesn't exist
-- Error: column animals.description does not exist

-- ============================================================================
-- SAFETY CHECKS AND PREPARATION
-- ============================================================================

-- Create a function to safely add column if it doesn't exist
CREATE OR REPLACE FUNCTION safe_add_column_if_not_exists(
    p_table_name text,
    p_column_name text,
    p_column_definition text
) RETURNS void AS $$
BEGIN
    -- Check if column exists
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = p_table_name 
        AND column_name = p_column_name
    ) THEN
        -- Column doesn't exist, add it
        EXECUTE format('ALTER TABLE %I ADD COLUMN %I %s', 
            p_table_name, 
            p_column_name, 
            p_column_definition
        );
        RAISE NOTICE 'Column %.% added successfully', p_table_name, p_column_name;
    ELSE
        -- Column already exists
        RAISE NOTICE 'Column %.% already exists - skipping', p_table_name, p_column_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MAIN MIGRATION
-- ============================================================================

-- Add description column to animals table (if it doesn't exist)
SELECT safe_add_column_if_not_exists(
    'animals',
    'description',
    'TEXT NULL'
);

-- Add comment to document the column's purpose
COMMENT ON COLUMN animals.description IS 'Optional description or notes about the animal';

-- ============================================================================
-- REFRESH POSTGREST SCHEMA CACHE
-- ============================================================================

-- Notify PostgREST to reload its schema cache
-- This ensures the API immediately recognizes the new column
NOTIFY pgrst, 'reload schema';

-- Alternative method: Update the schema cache timestamp
-- Some Supabase instances use this method
DO $$
BEGIN
    -- Try to update schema cache if the function exists
    IF EXISTS (
        SELECT 1 
        FROM pg_proc 
        WHERE proname = 'pgrst_watch' 
        OR proname = 'reload_schema_cache'
    ) THEN
        PERFORM pg_notify('pgrst', 'reload schema');
    END IF;
END $$;

-- ============================================================================
-- DATA MIGRATION (if needed)
-- ============================================================================

-- Set default descriptions for existing animals without descriptions
-- This is optional - uncomment if you want to populate existing records
/*
UPDATE animals 
SET description = 'No description provided'
WHERE description IS NULL
AND created_at < CURRENT_TIMESTAMP;
*/

-- ============================================================================
-- INDEXES (for performance)
-- ============================================================================

-- Create a GIN index for full-text search on description (optional)
-- Uncomment if you need to search within descriptions
/*
CREATE INDEX IF NOT EXISTS idx_animals_description_search 
ON animals 
USING gin(to_tsvector('english', COALESCE(description, '')));
*/

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Note: The description column inherits the existing RLS policies on the animals table
-- No additional policies needed as the table-level policies already control access

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify the column was added successfully
DO $$
DECLARE
    v_column_exists boolean;
    v_column_type text;
    v_is_nullable text;
BEGIN
    SELECT 
        EXISTS (
            SELECT 1 
            FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'animals' 
            AND column_name = 'description'
        ) INTO v_column_exists;
    
    IF v_column_exists THEN
        -- Get column details
        SELECT 
            data_type,
            is_nullable
        INTO 
            v_column_type,
            v_is_nullable
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'animals' 
        AND column_name = 'description';
        
        RAISE NOTICE '✅ SUCCESS: Column animals.description exists';
        RAISE NOTICE '   Type: %, Nullable: %', v_column_type, v_is_nullable;
    ELSE
        RAISE EXCEPTION '❌ FAILED: Column animals.description was not created';
    END IF;
END $$;

-- ============================================================================
-- ROLLBACK SCRIPT (save for emergency use)
-- ============================================================================

-- To rollback this migration, run:
-- ALTER TABLE animals DROP COLUMN IF EXISTS description;

-- ============================================================================
-- CLEANUP
-- ============================================================================

-- Drop the temporary function
DROP FUNCTION IF EXISTS safe_add_column_if_not_exists(text, text, text);

-- ============================================================================
-- FINAL VERIFICATION
-- ============================================================================

-- Display current animals table structure
-- This will show in the migration output for verification
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'animals'
ORDER BY ordinal_position;

-- Display success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration completed successfully!';
    RAISE NOTICE 'The animals.description column is now available.';
    RAISE NOTICE 'PostgREST schema cache has been refreshed.';
    RAISE NOTICE '========================================';
END $$;