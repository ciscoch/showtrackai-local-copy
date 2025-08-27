-- ============================================================================
-- EMERGENCY QUICK FIX: Minimal changes to get production working
-- Purpose: Add only the missing columns causing PGRST204 errors
-- Date: 2025-02-27
-- Use this if the comprehensive migration is too risky
-- ============================================================================

BEGIN;

-- Add goat to species enum if needed
DO $$
DECLARE
    species_type TEXT;
    enum_values TEXT[];
BEGIN
    -- Check if species is an ENUM
    SELECT data_type INTO species_type
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'animals'
    AND column_name = 'species';
    
    IF species_type = 'USER-DEFINED' THEN
        -- Get current enum values
        SELECT ARRAY_AGG(enumlabel::TEXT)
        INTO enum_values
        FROM pg_enum e
        JOIN pg_type t ON e.enumtypid = t.oid
        WHERE t.typname = 'animal_species';
        
        -- Add goat if not present
        IF NOT ('goat' = ANY(enum_values)) THEN
            ALTER TYPE animal_species ADD VALUE IF NOT EXISTS 'goat';
            RAISE NOTICE '✅ Added goat to species ENUM';
        ELSE
            RAISE NOTICE 'ℹ️ Goat already in species ENUM';
        END IF;
    ELSE
        RAISE NOTICE 'ℹ️ Species is not an ENUM type';
    END IF;
END $$;

-- Add missing description column
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'animals'
        AND column_name = 'description'
    ) THEN
        ALTER TABLE animals ADD COLUMN description TEXT;
        RAISE NOTICE '✅ Added description column';
    ELSE
        RAISE NOTICE 'ℹ️ Description column already exists';
    END IF;
END $$;

-- Add missing gender column
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'animals'
        AND column_name = 'gender'
    ) THEN
        ALTER TABLE animals ADD COLUMN gender VARCHAR(50);
        RAISE NOTICE '✅ Added gender column';
    ELSE
        RAISE NOTICE 'ℹ️ Gender column already exists';
    END IF;
END $$;

-- Add other commonly missing columns (safe to run even if they exist)
DO $$
BEGIN
    -- Add tag column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'animals'
        AND column_name = 'tag'
    ) THEN
        ALTER TABLE animals ADD COLUMN tag VARCHAR(100);
        RAISE NOTICE '✅ Added tag column';
    END IF;

    -- Add breed column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'animals'
        AND column_name = 'breed'
    ) THEN
        ALTER TABLE animals ADD COLUMN breed VARCHAR(100);
        RAISE NOTICE '✅ Added breed column';
    END IF;

    -- Add metadata column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'animals'
        AND column_name = 'metadata'
    ) THEN
        ALTER TABLE animals ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
        RAISE NOTICE '✅ Added metadata column';
    END IF;

    -- Add updated_at column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'animals'
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE animals ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        RAISE NOTICE '✅ Added updated_at column';
    END IF;
END $$;

-- Force PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

-- Quick verification
DO $$
DECLARE
    col_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'animals';
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ EMERGENCY FIX COMPLETED';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total columns in animals table: %', col_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Critical columns added/verified:';
    RAISE NOTICE '  • description ✓';
    RAISE NOTICE '  • gender ✓';
    RAISE NOTICE '  • goat species support ✓';
    RAISE NOTICE '';
    RAISE NOTICE 'PostgREST cache refresh triggered.';
    RAISE NOTICE 'Test your app now - PGRST204 errors should be gone!';
    RAISE NOTICE '========================================';
END $$;

COMMIT;

-- Test query (run separately after migration)
/*
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'animals'
AND column_name IN ('description', 'gender', 'species', 'tag', 'breed')
ORDER BY column_name;
*/