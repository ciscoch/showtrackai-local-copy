-- Migration: Complete Animals Table Schema Fix
-- Description: Adds all missing columns to the animals table based on the application's Animal model
-- Date: 2025-01-27
-- This migration is idempotent - safe to run multiple times

-- Start transaction for atomicity
BEGIN;

-- Function to safely add columns if they don't exist
CREATE OR REPLACE FUNCTION add_column_if_not_exists(
    p_table_name TEXT,
    p_column_name TEXT,
    p_column_definition TEXT
)
RETURNS VOID AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = p_table_name
        AND column_name = p_column_name
    ) THEN
        EXECUTE format('ALTER TABLE %I ADD COLUMN %I %s', p_table_name, p_column_name, p_column_definition);
        RAISE NOTICE 'Column %.% added successfully', p_table_name, p_column_name;
    ELSE
        RAISE NOTICE 'Column %.% already exists - skipping', p_table_name, p_column_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Add all potentially missing columns to animals table
-- Core identification columns
SELECT add_column_if_not_exists('animals', 'name', 'VARCHAR(255) NOT NULL DEFAULT ''Unknown''');
SELECT add_column_if_not_exists('animals', 'tag', 'VARCHAR(100)');
SELECT add_column_if_not_exists('animals', 'species', 'VARCHAR(50)');
SELECT add_column_if_not_exists('animals', 'breed', 'VARCHAR(100)');

-- Gender column (was missing in production)
SELECT add_column_if_not_exists('animals', 'gender', 'VARCHAR(20)');

-- Date columns
SELECT add_column_if_not_exists('animals', 'birth_date', 'DATE');
SELECT add_column_if_not_exists('animals', 'purchase_date', 'DATE');

-- Weight columns
SELECT add_column_if_not_exists('animals', 'purchase_weight', 'DECIMAL(10,2)');
SELECT add_column_if_not_exists('animals', 'current_weight', 'DECIMAL(10,2)');

-- Financial column
SELECT add_column_if_not_exists('animals', 'purchase_price', 'DECIMAL(10,2)');

-- Description column (was missing in production)
SELECT add_column_if_not_exists('animals', 'description', 'TEXT');

-- Photo URL column
SELECT add_column_if_not_exists('animals', 'photo_url', 'TEXT');

-- Metadata JSONB column for extensibility
SELECT add_column_if_not_exists('animals', 'metadata', 'JSONB DEFAULT ''{}''::jsonb');

-- Timestamp columns
SELECT add_column_if_not_exists('animals', 'created_at', 'TIMESTAMP WITH TIME ZONE DEFAULT NOW()');
SELECT add_column_if_not_exists('animals', 'updated_at', 'TIMESTAMP WITH TIME ZONE DEFAULT NOW()');

-- Ensure primary key exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE table_schema = 'public'
        AND table_name = 'animals'
        AND constraint_type = 'PRIMARY KEY'
    ) THEN
        -- Add id column if it doesn't exist
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'animals'
            AND column_name = 'id'
        ) THEN
            ALTER TABLE animals ADD COLUMN id UUID DEFAULT gen_random_uuid() PRIMARY KEY;
            RAISE NOTICE 'Added id column with primary key';
        ELSE
            -- If id exists but no primary key, add the constraint
            ALTER TABLE animals ADD CONSTRAINT animals_pkey PRIMARY KEY (id);
            RAISE NOTICE 'Added primary key constraint on id column';
        END IF;
    END IF;
END $$;

-- Ensure user_id foreign key column exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'animals'
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE animals ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
        RAISE NOTICE 'Added user_id column with foreign key';
    END IF;
END $$;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_animals_user_id ON animals(user_id);
CREATE INDEX IF NOT EXISTS idx_animals_species ON animals(species);
CREATE INDEX IF NOT EXISTS idx_animals_created_at ON animals(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_animals_tag ON animals(tag) WHERE tag IS NOT NULL;

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create or replace the trigger for updated_at
DROP TRIGGER IF EXISTS update_animals_updated_at ON animals;
CREATE TRIGGER update_animals_updated_at
    BEFORE UPDATE ON animals
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add check constraints for data validation
DO $$
BEGIN
    -- Gender constraint
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.check_constraints
        WHERE constraint_schema = 'public'
        AND constraint_name = 'animals_gender_check'
    ) THEN
        ALTER TABLE animals ADD CONSTRAINT animals_gender_check 
        CHECK (gender IS NULL OR gender IN ('Male', 'Female', 'Steer', 'Heifer', 'Gilt', 'Barrow', 'Wether', 'Unknown'));
        RAISE NOTICE 'Added gender check constraint';
    END IF;

    -- Weight constraints
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.check_constraints
        WHERE constraint_schema = 'public'
        AND constraint_name = 'animals_weight_positive'
    ) THEN
        ALTER TABLE animals ADD CONSTRAINT animals_weight_positive
        CHECK (
            (purchase_weight IS NULL OR purchase_weight >= 0) AND
            (current_weight IS NULL OR current_weight >= 0)
        );
        RAISE NOTICE 'Added weight positive check constraint';
    END IF;

    -- Price constraint
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.check_constraints
        WHERE constraint_schema = 'public'
        AND constraint_name = 'animals_price_positive'
    ) THEN
        ALTER TABLE animals ADD CONSTRAINT animals_price_positive
        CHECK (purchase_price IS NULL OR purchase_price >= 0);
        RAISE NOTICE 'Added price positive check constraint';
    END IF;
END $$;

-- Enable Row Level Security if not already enabled
ALTER TABLE animals ENABLE ROW LEVEL SECURITY;

-- Create RLS policies if they don't exist
DO $$
BEGIN
    -- Drop existing policies to recreate them
    DROP POLICY IF EXISTS "Users can view own animals" ON animals;
    DROP POLICY IF EXISTS "Users can insert own animals" ON animals;
    DROP POLICY IF EXISTS "Users can update own animals" ON animals;
    DROP POLICY IF EXISTS "Users can delete own animals" ON animals;

    -- Create comprehensive RLS policies
    CREATE POLICY "Users can view own animals"
        ON animals FOR SELECT
        USING (auth.uid() = user_id);

    CREATE POLICY "Users can insert own animals"
        ON animals FOR INSERT
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can update own animals"
        ON animals FOR UPDATE
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can delete own animals"
        ON animals FOR DELETE
        USING (auth.uid() = user_id);

    RAISE NOTICE 'RLS policies created/updated successfully';
END $$;

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- Clean up temporary function
DROP FUNCTION IF EXISTS add_column_if_not_exists(TEXT, TEXT, TEXT);

-- Commit transaction
COMMIT;

-- Verification queries (run outside transaction)
DO $$
DECLARE
    v_column_count INTEGER;
    v_missing_columns TEXT[];
    v_expected_columns TEXT[] := ARRAY[
        'id', 'user_id', 'name', 'tag', 'species', 'breed', 'gender',
        'birth_date', 'purchase_date', 'purchase_weight', 'current_weight',
        'purchase_price', 'description', 'photo_url', 'metadata',
        'created_at', 'updated_at'
    ];
    v_col TEXT;
BEGIN
    -- Check all expected columns exist
    SELECT COUNT(*)
    INTO v_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'animals'
    AND column_name = ANY(v_expected_columns);

    -- Find any missing columns
    v_missing_columns := ARRAY[]::TEXT[];
    FOREACH v_col IN ARRAY v_expected_columns
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'animals'
            AND column_name = v_col
        ) THEN
            v_missing_columns := array_append(v_missing_columns, v_col);
        END IF;
    END LOOP;

    -- Report results
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ANIMALS TABLE VERIFICATION RESULTS:';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Expected columns: %', array_length(v_expected_columns, 1);
    RAISE NOTICE 'Found columns: %', v_column_count;
    
    IF array_length(v_missing_columns, 1) > 0 THEN
        RAISE WARNING 'Missing columns: %', v_missing_columns;
    ELSE
        RAISE NOTICE '✓ All expected columns are present';
    END IF;

    -- Display current table structure
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CURRENT TABLE STRUCTURE:';
    RAISE NOTICE '========================================';
    FOR v_col IN
        SELECT column_name || ' ' || 
               COALESCE(data_type || 
                       CASE 
                           WHEN character_maximum_length IS NOT NULL 
                           THEN '(' || character_maximum_length || ')'
                           WHEN numeric_precision IS NOT NULL
                           THEN '(' || numeric_precision || ',' || numeric_scale || ')'
                           ELSE ''
                       END, 'unknown') ||
               CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END ||
               COALESCE(' DEFAULT ' || column_default, '') AS column_info
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'animals'
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE '  - %', v_col;
    END LOOP;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration completed successfully!';
    RAISE NOTICE '========================================';
END $$;

-- Final verification query to run manually
/*
-- Run this query to verify the table structure:
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    numeric_precision,
    numeric_scale,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'animals'
ORDER BY ordinal_position;

-- Check for any missing columns:
WITH expected_columns AS (
    SELECT unnest(ARRAY[
        'id', 'user_id', 'name', 'tag', 'species', 'breed', 'gender',
        'birth_date', 'purchase_date', 'purchase_weight', 'current_weight',
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
    CASE WHEN a.column_name IS NULL THEN 'MISSING' ELSE 'EXISTS' END AS status
FROM expected_columns e
LEFT JOIN actual_columns a ON e.column_name = a.column_name
ORDER BY 
    CASE WHEN a.column_name IS NULL THEN 0 ELSE 1 END,
    e.column_name;

-- Test insert to verify all columns work:
INSERT INTO animals (
    user_id, name, tag, species, breed, gender,
    birth_date, purchase_date, purchase_weight, current_weight,
    purchase_price, description, photo_url, metadata
) VALUES (
    auth.uid(), 
    'Test Animal', 
    'TEST-001', 
    'Cattle', 
    'Angus', 
    'Steer',
    '2024-01-01'::date, 
    '2024-06-01'::date, 
    500.00, 
    750.00,
    2500.00, 
    'Test description for verification', 
    'https://example.com/photo.jpg',
    '{"test": true}'::jsonb
) 
ON CONFLICT DO NOTHING
RETURNING *;

-- Clean up test data:
DELETE FROM animals WHERE tag = 'TEST-001' AND metadata->>'test' = 'true';
*/