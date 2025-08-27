-- CRITICAL FIX: Add missing description column to animals table
-- Purpose: Fix PGRST204 error - "Could not find the 'description' column"
-- Issue: Application expects description field but database table is missing it
-- Date: 2025-02-27

-- ============================================================================
-- DIAGNOSTIC: Check current animals table structure
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Starting animals table description column fix';
    RAISE NOTICE 'Checking current table structure...';
END $$;

-- Create the animals table if it doesn't exist (should exist but being safe)
CREATE TABLE IF NOT EXISTS animals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name VARCHAR(255) NOT NULL,
    tag VARCHAR(100),
    species VARCHAR(50) NOT NULL,
    breed VARCHAR(100),
    gender VARCHAR(50),
    birth_date DATE,
    purchase_weight DECIMAL(10,2),
    current_weight DECIMAL(10,2),
    purchase_date DATE,
    purchase_price DECIMAL(10,2),
    photo_url TEXT,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- STEP 1: Add missing description column
-- ============================================================================

-- Check if description column exists
DO $$
DECLARE
    column_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'animals' 
        AND column_name = 'description'
    ) INTO column_exists;
    
    IF column_exists THEN
        RAISE NOTICE '✅ Description column already exists';
    ELSE
        RAISE NOTICE '❌ Description column missing - adding now';
        
        -- Add the description column
        ALTER TABLE animals ADD COLUMN description TEXT;
        
        RAISE NOTICE '✅ Description column added successfully';
    END IF;
END $$;

-- ============================================================================
-- STEP 2: Ensure all expected columns exist
-- ============================================================================

-- Add any other potentially missing columns that the Dart model expects

-- Check and add tag unique constraint if needed
DO $$
BEGIN
    -- Add unique constraint on (user_id, tag) if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'animals' 
        AND constraint_type = 'UNIQUE' 
        AND constraint_name LIKE '%tag%'
    ) THEN
        ALTER TABLE animals ADD CONSTRAINT animals_user_id_tag_unique UNIQUE(user_id, tag);
        RAISE NOTICE '✅ Added unique constraint on (user_id, tag)';
    END IF;
END $$;

-- ============================================================================
-- STEP 3: Create necessary indexes for performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_animals_user_id ON animals(user_id);
CREATE INDEX IF NOT EXISTS idx_animals_species ON animals(species);
CREATE INDEX IF NOT EXISTS idx_animals_tag ON animals(tag);
CREATE INDEX IF NOT EXISTS idx_animals_updated_at ON animals(updated_at DESC);

-- ============================================================================
-- STEP 4: Enable RLS if not already enabled
-- ============================================================================

ALTER TABLE animals ENABLE ROW LEVEL SECURITY;

-- Create basic RLS policies if they don't exist
DO $$
BEGIN
    -- Check if SELECT policy exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'animals' 
        AND policyname = 'users_select_own_animals' 
        AND cmd = 'SELECT'
    ) THEN
        CREATE POLICY "users_select_own_animals" ON animals
        FOR SELECT USING (auth.uid() = user_id);
        RAISE NOTICE '✅ Created SELECT policy';
    END IF;
    
    -- Check if INSERT policy exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'animals' 
        AND policyname = 'users_insert_own_animals' 
        AND cmd = 'INSERT'
    ) THEN
        CREATE POLICY "users_insert_own_animals" ON animals
        FOR INSERT WITH CHECK (auth.uid() = user_id);
        RAISE NOTICE '✅ Created INSERT policy';
    END IF;
    
    -- Check if UPDATE policy exists (use the hotfix version)
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'animals' 
        AND policyname LIKE '%update%' 
        AND cmd = 'UPDATE'
    ) THEN
        CREATE POLICY "users_update_own_animals" ON animals
        FOR UPDATE 
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);
        RAISE NOTICE '✅ Created UPDATE policy';
    END IF;
    
    -- Check if DELETE policy exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'animals' 
        AND policyname = 'users_delete_own_animals' 
        AND cmd = 'DELETE'
    ) THEN
        CREATE POLICY "users_delete_own_animals" ON animals
        FOR DELETE USING (auth.uid() = user_id);
        RAISE NOTICE '✅ Created DELETE policy';
    END IF;
END $$;

-- ============================================================================
-- STEP 5: Grant necessary permissions
-- ============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON animals TO authenticated;

-- ============================================================================
-- STEP 6: Force PostgREST schema cache refresh
-- ============================================================================

-- Send notification to PostgREST to refresh schema cache
NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'animals'
ORDER BY ordinal_position;

-- Verify RLS policies
SELECT 
    policyname, 
    cmd, 
    permissive,
    qual::text as using_clause,
    with_check::text as with_check_clause
FROM pg_policies 
WHERE tablename = 'animals' 
AND schemaname = 'public'
ORDER BY cmd, policyname;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '🎉 Animals table description column fix completed!';
    RAISE NOTICE '📋 What was fixed:';
    RAISE NOTICE '   ✅ Added missing description column';
    RAISE NOTICE '   ✅ Ensured all indexes exist';
    RAISE NOTICE '   ✅ Verified RLS policies';
    RAISE NOTICE '   ✅ Notified PostgREST to refresh schema cache';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Test the fix:';
    RAISE NOTICE '   1. Try updating an animal with description field';
    RAISE NOTICE '   2. Should no longer get PGRST204 error';
    RAISE NOTICE '   3. All CRUD operations should work normally';
END $$;

-- ============================================================================
-- TESTING SCRIPT (Run after migration)
-- ============================================================================

/*
Test the fix with these queries:

1. Verify description column exists:
   SELECT column_name FROM information_schema.columns 
   WHERE table_name = 'animals' AND column_name = 'description';

2. Test INSERT with description:
   INSERT INTO animals (user_id, name, species, description) 
   VALUES (auth.uid(), 'Test Animal', 'cattle', 'Test description')
   RETURNING id, name, description;

3. Test UPDATE with description:
   UPDATE animals 
   SET description = 'Updated description', updated_at = NOW()
   WHERE id = 'your-animal-id' AND user_id = auth.uid()
   RETURNING id, name, description, updated_at;

4. Test via Supabase REST API:
   PATCH /rest/v1/animals?id=eq.ANIMAL_ID&user_id=eq.USER_ID
   Content-Type: application/json
   {
     "name": "Updated Name",
     "description": "Updated description"
   }

Expected result: No more PGRST204 errors!
*/