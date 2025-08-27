-- RLS Policy Debug and Fix for Animal Updates
-- Run this to diagnose and fix RLS policy issues

-- Step 1: Check current RLS status
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'animals';

-- Step 2: Check existing policies
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    permissive,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'animals'
ORDER BY cmd;

-- Step 3: Test RLS policy logic (replace 'user-id-here' with actual user ID)
-- This helps identify if the issue is with USING or WITH CHECK clauses
/*
-- Test as specific user (replace with actual user ID from failing saves)
SET request.jwt.claim.sub = 'user-id-here';

-- Test if user can see their animals (SELECT policy)
SELECT id, name, user_id FROM animals WHERE user_id = 'user-id-here' LIMIT 1;

-- Test if user can update (both USING and WITH CHECK must pass)
-- This will show which policy is failing
UPDATE animals 
SET updated_at = NOW() 
WHERE id = 'animal-id-here' 
AND user_id = 'user-id-here';
*/

-- Step 4: Enhanced UPDATE policy that's more permissive
-- Only run this if the current policy is too restrictive

DROP POLICY IF EXISTS "Users can update own animals" ON public.animals;

CREATE POLICY "Users can update own animals enhanced" 
ON public.animals 
FOR UPDATE 
USING (
    -- Allow update if user owns the animal
    auth.uid() = user_id
)
WITH CHECK (
    -- Ensure the user_id doesn't change to someone else's
    auth.uid() = user_id
);

-- Step 5: Add debugging policy (temporary - remove after debugging)
-- This allows more detailed error logging

CREATE OR REPLACE FUNCTION debug_animal_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Log update attempts for debugging
    RAISE NOTICE 'Animal update attempt: user_id=%, animal_id=%, auth_uid=%', 
        NEW.user_id, NEW.id, auth.uid();
    
    -- Check if user_id is being changed (security issue)
    IF OLD.user_id != NEW.user_id THEN
        RAISE EXCEPTION 'Cannot change animal owner (user_id)';
    END IF;
    
    -- Check if user matches
    IF auth.uid() != NEW.user_id THEN
        RAISE EXCEPTION 'User % cannot update animal owned by %', 
            auth.uid(), NEW.user_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger for debugging (remove after issue is resolved)
DROP TRIGGER IF EXISTS debug_animal_update_trigger ON public.animals;
CREATE TRIGGER debug_animal_update_trigger
    BEFORE UPDATE ON public.animals
    FOR EACH ROW
    EXECUTE FUNCTION debug_animal_update();

-- Step 6: Test update with enhanced logging
-- Run this to test if updates work with debugging enabled

COMMENT ON TRIGGER debug_animal_update_trigger ON public.animals IS 
'Temporary debugging trigger - remove after animal update issue is resolved';

-- Step 7: Check for conflicting constraints
-- Verify the unique constraint isn't causing issues
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    conkey as constrained_columns,
    confkey as referenced_columns
FROM pg_constraint 
WHERE conrelid = 'public.animals'::regclass
ORDER BY conname;

-- Step 8: Performance check - ensure indexes support RLS policies
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public' 
AND tablename = 'animals'
ORDER BY indexname;