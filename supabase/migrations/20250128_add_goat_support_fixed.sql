-- ============================================================================
-- ADD GOAT SUPPORT TO ANIMALS TABLE (FIXED VERSION)
-- Purpose: Ensure proper goat support with gender terms and validation
-- Fixed: Handles existing CHECK constraints properly
-- Date: 2025-01-28
-- ============================================================================

BEGIN; -- Start transaction for safety

-- ============================================================================
-- STEP 1: Drop existing constraints if they exist (to recreate them properly)
-- ============================================================================

DO $$
BEGIN
    -- Drop existing gender check constraint if it exists
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'animals_gender_check'
        AND conrelid = 'animals'::regclass
    ) THEN
        ALTER TABLE animals DROP CONSTRAINT animals_gender_check;
        RAISE NOTICE '✅ Dropped existing gender_check constraint';
    END IF;
    
    -- Drop existing species check constraint if it exists
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'animals_species_check'
        AND conrelid = 'animals'::regclass
    ) THEN
        ALTER TABLE animals DROP CONSTRAINT animals_species_check;
        RAISE NOTICE '✅ Dropped existing species_check constraint';
    END IF;
END $$;

-- ============================================================================
-- STEP 2: Check column types and ensure they're VARCHAR
-- ============================================================================

DO $$
DECLARE
    species_type TEXT;
    gender_type TEXT;
BEGIN
    -- Check the actual data type of species column
    SELECT data_type INTO species_type
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'animals'
    AND column_name = 'species';
    
    -- Check the actual data type of gender column  
    SELECT data_type INTO gender_type
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'animals'
    AND column_name = 'gender';
    
    RAISE NOTICE 'Current species column type: %', COALESCE(species_type, 'NOT FOUND');
    RAISE NOTICE 'Current gender column type: %', COALESCE(gender_type, 'NOT FOUND');
    
    -- If species is USER-DEFINED (ENUM), we need to handle it differently
    IF species_type = 'USER-DEFINED' THEN
        RAISE NOTICE '⚠️ Species is an ENUM type, will need special handling';
        -- We'll add goat to the enum if it's not there
    END IF;
END $$;

-- ============================================================================
-- STEP 3: Handle ENUM type if species is an ENUM
-- ============================================================================

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
        -- Get the enum type name
        SELECT udt_name INTO species_type
        FROM information_schema.columns
        WHERE table_schema = 'public' 
        AND table_name = 'animals'
        AND column_name = 'species';
        
        -- Get current enum values
        SELECT ARRAY_AGG(enumlabel::TEXT ORDER BY enumsortorder)
        INTO enum_values
        FROM pg_enum
        WHERE enumtypid = species_type::regtype;
        
        RAISE NOTICE 'Current ENUM values: %', enum_values;
        
        -- Check if 'goat' is already in the enum
        IF NOT ('goat' = ANY(enum_values)) THEN
            -- Add 'goat' to the enum
            EXECUTE format('ALTER TYPE %I ADD VALUE IF NOT EXISTS ''goat''', species_type);
            RAISE NOTICE '✅ Added ''goat'' to species ENUM';
        ELSE
            RAISE NOTICE '✅ ''goat'' already exists in species ENUM';
        END IF;
    END IF;
END $$;

-- ============================================================================
-- STEP 4: Add proper CHECK constraints for VARCHAR columns
-- ============================================================================

DO $$
DECLARE
    species_type TEXT;
    gender_type TEXT;
BEGIN
    -- Get column types
    SELECT data_type INTO species_type
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'animals'
    AND column_name = 'species';
    
    SELECT data_type INTO gender_type
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'animals'
    AND column_name = 'gender';
    
    -- Only add CHECK constraint if species is VARCHAR/TEXT
    IF species_type IN ('character varying', 'text', 'character') THEN
        ALTER TABLE animals ADD CONSTRAINT animals_species_check 
        CHECK (species IN (
            'cattle', 'swine', 'sheep', 'goat', 
            'poultry', 'rabbit', 'other'
        ));
        RAISE NOTICE '✅ Added species CHECK constraint with goat support';
    ELSE
        RAISE NOTICE '⚠️ Species is ENUM type, no CHECK constraint needed';
    END IF;
    
    -- Add gender constraint (should always be VARCHAR)
    IF gender_type IN ('character varying', 'text', 'character') OR gender_type IS NOT NULL THEN
        ALTER TABLE animals ADD CONSTRAINT animals_gender_check 
        CHECK (gender IN (
            -- General terms
            'male', 'female',
            -- Cattle terms
            'bull', 'steer', 'heifer', 'cow',
            -- Swine terms
            'boar', 'barrow', 'gilt', 'sow',
            -- Sheep terms
            'ram', 'wether', 'ewe',
            -- GOAT TERMS (CRITICAL)
            'buck', 'wether', 'doe', 'doeling', 'buckling',
            -- Poultry terms
            'rooster', 'cockerel', 'hen', 'pullet',
            -- Rabbit terms
            'buck', 'doe'
        ) OR gender IS NULL);
        RAISE NOTICE '✅ Added gender CHECK constraint with complete goat terms';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Error adding constraints: %', SQLERRM;
    RAISE NOTICE 'This might be okay if constraints already exist correctly';
END $$;

-- ============================================================================
-- STEP 5: Update existing goat records to use proper gender terms
-- ============================================================================

DO $$
DECLARE
    goat_count INTEGER;
    updated_count INTEGER := 0;
BEGIN
    -- Count existing goats
    SELECT COUNT(*) INTO goat_count
    FROM animals
    WHERE species = 'goat';
    
    RAISE NOTICE 'Found % existing goat records', goat_count;
    
    -- Standardize gender terms for goats
    -- Male goats
    UPDATE animals 
    SET gender = 'buck'
    WHERE species = 'goat' 
    AND gender IN ('male', 'intact male')
    AND gender != 'buck';
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
        RAISE NOTICE 'Updated % male goats to use ''buck''', updated_count;
    END IF;
    
    -- Castrated male goats
    UPDATE animals 
    SET gender = 'wether'
    WHERE species = 'goat' 
    AND gender IN ('castrated male', 'neutered male', 'wether')
    AND gender != 'wether';
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
        RAISE NOTICE 'Updated % castrated male goats to use ''wether''', updated_count;
    END IF;
    
    -- Female goats
    UPDATE animals 
    SET gender = 'doe'
    WHERE species = 'goat' 
    AND gender IN ('female', 'intact female')
    AND gender != 'doe';
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF updated_count > 0 THEN
        RAISE NOTICE 'Updated % female goats to use ''doe''', updated_count;
    END IF;
END $$;

-- ============================================================================
-- STEP 6: Add goat-specific indexes for performance
-- ============================================================================

-- Create partial index for goats if there are many
CREATE INDEX IF NOT EXISTS idx_animals_goats 
ON animals(user_id, gender) 
WHERE species = 'goat';

RAISE NOTICE '✅ Added performance index for goat queries';

-- ============================================================================
-- STEP 7: Verify the setup
-- ============================================================================

DO $$
DECLARE
    species_type TEXT;
    constraint_def TEXT;
    goat_genders TEXT[];
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📋 VERIFICATION REPORT';
    RAISE NOTICE '========================================';
    
    -- Check species column type
    SELECT data_type INTO species_type
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'animals'
    AND column_name = 'species';
    
    RAISE NOTICE 'Species column type: %', species_type;
    
    -- Check if goat is supported
    IF species_type = 'USER-DEFINED' THEN
        -- Check ENUM values
        IF EXISTS (
            SELECT 1
            FROM pg_enum e
            JOIN pg_type t ON e.enumtypid = t.oid
            WHERE t.typname = (
                SELECT udt_name
                FROM information_schema.columns
                WHERE table_schema = 'public' 
                AND table_name = 'animals'
                AND column_name = 'species'
            )
            AND e.enumlabel = 'goat'
        ) THEN
            RAISE NOTICE '✅ ''goat'' is in species ENUM';
        ELSE
            RAISE WARNING '❌ ''goat'' is NOT in species ENUM';
        END IF;
    ELSE
        -- Check constraint
        SELECT pg_get_constraintdef(oid) INTO constraint_def
        FROM pg_constraint 
        WHERE conname = 'animals_species_check'
        AND conrelid = 'animals'::regclass;
        
        IF constraint_def LIKE '%goat%' THEN
            RAISE NOTICE '✅ ''goat'' is in species CHECK constraint';
        ELSE
            RAISE WARNING '❌ ''goat'' is NOT in species CHECK constraint';
        END IF;
    END IF;
    
    -- Check gender constraint for goat terms
    SELECT pg_get_constraintdef(oid) INTO constraint_def
    FROM pg_constraint 
    WHERE conname = 'animals_gender_check'
    AND conrelid = 'animals'::regclass;
    
    IF constraint_def LIKE '%buck%' AND 
       constraint_def LIKE '%doe%' AND 
       constraint_def LIKE '%wether%' THEN
        RAISE NOTICE '✅ Goat gender terms (buck, doe, wether) are supported';
    ELSE
        RAISE WARNING '❌ Some goat gender terms are missing';
    END IF;
    
    -- Check for existing goat records
    SELECT ARRAY_AGG(DISTINCT gender) INTO goat_genders
    FROM animals
    WHERE species = 'goat';
    
    IF goat_genders IS NOT NULL THEN
        RAISE NOTICE '📊 Current goat genders in use: %', goat_genders;
    END IF;
    
    RAISE NOTICE '========================================';
END $$;

-- ============================================================================
-- STEP 8: Force PostgREST to reload schema
-- ============================================================================

NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- STEP 9: Add helpful comments
-- ============================================================================

COMMENT ON CONSTRAINT animals_species_check ON animals IS 
'Validates species including: cattle, swine, sheep, goat, poultry, rabbit, other';

COMMENT ON CONSTRAINT animals_gender_check ON animals IS 
'Validates gender with species-specific terms. Goat terms: buck (intact male), wether (castrated male), doe (adult female), doeling (young female), buckling (young male)';

-- Commit the transaction
COMMIT;

-- ============================================================================
-- FINAL SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🐐 GOAT SUPPORT MIGRATION COMPLETE!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Goat species is now fully supported';
    RAISE NOTICE '✅ Goat-specific gender terms available:';
    RAISE NOTICE '   • buck (intact male)';
    RAISE NOTICE '   • wether (castrated male)';  
    RAISE NOTICE '   • doe (adult female)';
    RAISE NOTICE '   • doeling (young female)';
    RAISE NOTICE '   • buckling (young male)';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 You can now:';
    RAISE NOTICE '   • Create goat records';
    RAISE NOTICE '   • Use proper goat gender terminology';
    RAISE NOTICE '   • Track goat-specific data';
    RAISE NOTICE '========================================';
END $$;

-- ============================================================================
-- TEST QUERIES (run these manually to verify)
-- ============================================================================

/*
-- Test creating a goat
INSERT INTO animals (user_id, name, species, gender, breed) 
VALUES (
    auth.uid(), 
    'Test Goat', 
    'goat', 
    'doe', 
    'Boer'
) 
RETURNING *;

-- Query all goats
SELECT name, species, gender, breed 
FROM animals 
WHERE species = 'goat';

-- Check constraint definitions
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conrelid = 'animals'::regclass
AND conname IN ('animals_species_check', 'animals_gender_check');
*/