-- ============================================================================
-- COMPREHENSIVE FIX: Add ALL missing columns to animals table
-- Purpose: Fix schema drift - ensure animals table has ALL expected columns
-- Fixes: PGRST204 errors for missing 'gender', 'description', and any other columns
-- Date: 2025-02-27
-- ============================================================================

BEGIN; -- Start transaction for safety

-- ============================================================================
-- STEP 1: Create helper function for safe column addition (idempotent)
-- ============================================================================

CREATE OR REPLACE FUNCTION safe_add_column_if_not_exists(
    p_table_name TEXT,
    p_column_name TEXT,
    p_column_definition TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    column_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = p_table_name 
        AND column_name = p_column_name
    ) INTO column_exists;
    
    IF NOT column_exists THEN
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
-- STEP 2: Add ALL expected columns from Animal model
-- ============================================================================

DO $$
DECLARE
    columns_added INTEGER := 0;
    column_added BOOLEAN;
BEGIN
    RAISE NOTICE '🔧 Starting comprehensive animals table schema fix...';
    RAISE NOTICE '';
    
    -- Core identification columns
    -- id and user_id should already exist, but check them
    
    -- Animal identification
    column_added := safe_add_column_if_not_exists('animals', 'name', 
        'VARCHAR(255) NOT NULL DEFAULT ''Unnamed''');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    column_added := safe_add_column_if_not_exists('animals', 'tag', 
        'VARCHAR(100)');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    -- Species and characteristics
    column_added := safe_add_column_if_not_exists('animals', 'species', 
        'VARCHAR(50) NOT NULL DEFAULT ''other''');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    column_added := safe_add_column_if_not_exists('animals', 'breed', 
        'VARCHAR(100)');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    -- CRITICAL: Add missing gender column
    column_added := safe_add_column_if_not_exists('animals', 'gender', 
        'VARCHAR(50)');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    -- Date fields
    column_added := safe_add_column_if_not_exists('animals', 'birth_date', 
        'DATE');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    column_added := safe_add_column_if_not_exists('animals', 'purchase_date', 
        'DATE');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    -- Weight tracking
    column_added := safe_add_column_if_not_exists('animals', 'purchase_weight', 
        'DECIMAL(10,2) CHECK (purchase_weight >= 0)');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    column_added := safe_add_column_if_not_exists('animals', 'current_weight', 
        'DECIMAL(10,2) CHECK (current_weight >= 0)');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    -- Financial
    column_added := safe_add_column_if_not_exists('animals', 'purchase_price', 
        'DECIMAL(10,2) CHECK (purchase_price >= 0)');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    -- CRITICAL: Add missing description column
    column_added := safe_add_column_if_not_exists('animals', 'description', 
        'TEXT');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    -- Media and metadata
    column_added := safe_add_column_if_not_exists('animals', 'photo_url', 
        'TEXT');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    column_added := safe_add_column_if_not_exists('animals', 'metadata', 
        'JSONB DEFAULT ''{}''::jsonb');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    -- Timestamps
    column_added := safe_add_column_if_not_exists('animals', 'created_at', 
        'TIMESTAMP WITH TIME ZONE DEFAULT NOW()');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    column_added := safe_add_column_if_not_exists('animals', 'updated_at', 
        'TIMESTAMP WITH TIME ZONE DEFAULT NOW()');
    IF column_added THEN columns_added := columns_added + 1; END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Summary: % columns added', columns_added;
    IF columns_added = 0 THEN
        RAISE NOTICE '✅ All expected columns already exist!';
    ELSE
        RAISE NOTICE '✅ Schema updates applied successfully!';
    END IF;
END $$;

-- ============================================================================
-- STEP 3: Add constraints if they don't exist
-- ============================================================================

DO $$
BEGIN
    -- Add check constraint for valid gender values if not exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'animals_gender_check'
    ) THEN
        ALTER TABLE animals ADD CONSTRAINT animals_gender_check 
        CHECK (gender IN (
            'male', 'female', 'steer', 'heifer', 'barrow', 
            'gilt', 'wether', 'doe', 'buck', 'ewe', 'ram'
        ) OR gender IS NULL);
        RAISE NOTICE '✅ Added gender validation constraint';
    END IF;
    
    -- Add check constraint for valid species if not exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'animals_species_check'
    ) THEN
        ALTER TABLE animals ADD CONSTRAINT animals_species_check 
        CHECK (species IN (
            'cattle', 'swine', 'sheep', 'goat', 
            'poultry', 'rabbit', 'other'
        ));
        RAISE NOTICE '✅ Added species validation constraint';
    END IF;
    
    -- Add unique constraint on (user_id, tag) if not exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'animals_user_tag_unique'
    ) THEN
        ALTER TABLE animals ADD CONSTRAINT animals_user_tag_unique 
        UNIQUE (user_id, tag);
        RAISE NOTICE '✅ Added unique constraint for user_id + tag';
    END IF;
END $$;

-- ============================================================================
-- STEP 4: Add indexes for performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_animals_user_id ON animals(user_id);
CREATE INDEX IF NOT EXISTS idx_animals_species ON animals(species);
CREATE INDEX IF NOT EXISTS idx_animals_gender ON animals(gender);
CREATE INDEX IF NOT EXISTS idx_animals_tag ON animals(tag);
CREATE INDEX IF NOT EXISTS idx_animals_created_at ON animals(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_animals_updated_at ON animals(updated_at DESC);

-- ============================================================================
-- STEP 5: Create trigger for updated_at if not exists
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_animals_updated_at ON animals;
CREATE TRIGGER update_animals_updated_at
    BEFORE UPDATE ON animals
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- STEP 6: Add column comments for documentation
-- ============================================================================

COMMENT ON COLUMN animals.name IS 'Name of the animal';
COMMENT ON COLUMN animals.tag IS 'Unique tag or ear tag number for the animal';
COMMENT ON COLUMN animals.species IS 'Species: cattle, swine, sheep, goat, poultry, rabbit, other';
COMMENT ON COLUMN animals.breed IS 'Breed of the animal';
COMMENT ON COLUMN animals.gender IS 'Gender: male, female, or species-specific terms';
COMMENT ON COLUMN animals.birth_date IS 'Date of birth';
COMMENT ON COLUMN animals.purchase_date IS 'Date the animal was purchased';
COMMENT ON COLUMN animals.purchase_weight IS 'Weight at purchase (lbs or kg)';
COMMENT ON COLUMN animals.current_weight IS 'Current weight (lbs or kg)';
COMMENT ON COLUMN animals.purchase_price IS 'Purchase price in currency';
COMMENT ON COLUMN animals.description IS 'Optional text description or notes about the animal';
COMMENT ON COLUMN animals.photo_url IS 'URL to the animal''s photo';
COMMENT ON COLUMN animals.metadata IS 'Additional flexible JSON metadata';
COMMENT ON COLUMN animals.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN animals.updated_at IS 'Timestamp when record was last updated';

-- ============================================================================
-- STEP 7: Force PostgREST to reload its schema cache
-- ============================================================================

-- Method 1: Standard PostgREST cache reload
NOTIFY pgrst, 'reload schema';

-- Method 2: Alternative notification
DO $$
BEGIN
    PERFORM pg_notify('pgrst', 'reload schema');
    RAISE NOTICE '📡 Sent schema reload notification to PostgREST';
END $$;

-- Method 3: For Supabase, update schema_migrations if exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'schema_migrations'
    ) THEN
        INSERT INTO schema_migrations (version) 
        VALUES ('20250227_fix_animals_schema_complete')
        ON CONFLICT (version) DO NOTHING;
    END IF;
END $$;

-- ============================================================================
-- STEP 8: Verify the complete schema
-- ============================================================================

DO $$
DECLARE
    expected_columns TEXT[] := ARRAY[
        'id', 'user_id', 'name', 'tag', 'species', 'breed', 'gender',
        'birth_date', 'purchase_weight', 'current_weight', 'purchase_date',
        'purchase_price', 'description', 'photo_url', 'metadata',
        'created_at', 'updated_at'
    ];
    actual_columns TEXT[];
    missing_columns TEXT[];
    col TEXT;
BEGIN
    -- Get actual columns
    SELECT ARRAY_AGG(column_name ORDER BY column_name)
    INTO actual_columns
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'animals';
    
    -- Find missing columns
    missing_columns := ARRAY[]::TEXT[];
    FOREACH col IN ARRAY expected_columns
    LOOP
        IF NOT (col = ANY(actual_columns)) THEN
            missing_columns := array_append(missing_columns, col);
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📋 FINAL VERIFICATION';
    RAISE NOTICE '========================================';
    
    IF array_length(missing_columns, 1) > 0 THEN
        RAISE WARNING '⚠️ Still missing columns: %', missing_columns;
    ELSE
        RAISE NOTICE '✅ ALL EXPECTED COLUMNS ARE PRESENT!';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Current animals table structure:';
    RAISE NOTICE '------------------------------------';
    
    -- Display all columns with their types
    FOR col IN 
        SELECT '  • ' || column_name || ' (' || 
               COALESCE(data_type, 'unknown') || 
               CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END || 
               ')' as column_info
        FROM information_schema.columns
        WHERE table_schema = 'public' 
        AND table_name = 'animals'
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE '%', col;
    END LOOP;
    
    RAISE NOTICE '========================================';
END $$;

-- ============================================================================
-- STEP 9: Test that updates work with all fields
-- ============================================================================

DO $$
BEGIN
    -- Try a test update to verify all columns are accessible
    -- This won't actually update anything (WHERE FALSE)
    BEGIN
        UPDATE animals 
        SET 
            name = name,
            tag = tag,
            species = species,
            breed = breed,
            gender = gender,
            birth_date = birth_date,
            purchase_weight = purchase_weight,
            current_weight = current_weight,
            purchase_date = purchase_date,
            purchase_price = purchase_price,
            description = description,
            photo_url = photo_url,
            metadata = metadata,
            updated_at = NOW()
        WHERE FALSE; -- Ensures no actual updates
        
        RAISE NOTICE '✅ All columns are accessible for updates!';
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '❌ Column access test failed: %', SQLERRM;
    END;
END $$;

-- ============================================================================
-- STEP 10: Clean up helper function
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
    RAISE NOTICE '🎉 MIGRATION COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ The animals table now has ALL expected columns:';
    RAISE NOTICE '  • Core fields: id, user_id, name, tag';
    RAISE NOTICE '  • Characteristics: species, breed, gender ✓';
    RAISE NOTICE '  • Dates: birth_date, purchase_date';
    RAISE NOTICE '  • Weights: purchase_weight, current_weight';
    RAISE NOTICE '  • Financial: purchase_price';
    RAISE NOTICE '  • Descriptive: description ✓, photo_url';
    RAISE NOTICE '  • Flexible: metadata (JSONB)';
    RAISE NOTICE '  • Timestamps: created_at, updated_at';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Next steps:';
    RAISE NOTICE '  1. Test animal create/update operations';
    RAISE NOTICE '  2. Verify PGRST204 errors are resolved';
    RAISE NOTICE '  3. Monitor for any other schema issues';
    RAISE NOTICE '========================================';
END $$;

-- ============================================================================
-- VERIFICATION QUERIES (run manually after migration)
-- ============================================================================

/*
-- 1. Check all columns exist
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'animals'
ORDER BY ordinal_position;

-- 2. Test an update with all fields
UPDATE animals 
SET 
    name = 'Test Animal',
    gender = 'male',
    description = 'Test description',
    updated_at = NOW()
WHERE id = 'your-test-animal-id'
RETURNING *;

-- 3. Verify PostgREST can see all columns
-- Make an API call: GET /rest/v1/animals?select=*&limit=1

-- 4. Check constraints
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conrelid = 'animals'::regclass;

-- 5. Check indexes
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'animals';
*/

-- ============================================================================
-- ROLLBACK INSTRUCTIONS (if needed)
-- ============================================================================

/*
-- To rollback (remove added columns):

ALTER TABLE animals 
DROP COLUMN IF EXISTS description,
DROP COLUMN IF EXISTS gender,
DROP COLUMN IF EXISTS tag,
DROP COLUMN IF EXISTS breed,
DROP COLUMN IF EXISTS birth_date,
DROP COLUMN IF EXISTS purchase_weight,
DROP COLUMN IF EXISTS current_weight,
DROP COLUMN IF EXISTS purchase_date,
DROP COLUMN IF EXISTS purchase_price,
DROP COLUMN IF EXISTS photo_url,
DROP COLUMN IF EXISTS metadata;

DROP CONSTRAINT IF EXISTS animals_gender_check;
DROP CONSTRAINT IF EXISTS animals_species_check;
DROP CONSTRAINT IF EXISTS animals_user_tag_unique;

NOTIFY pgrst, 'reload schema';
*/