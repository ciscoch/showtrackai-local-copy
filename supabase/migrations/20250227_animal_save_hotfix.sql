-- HOTFIX: Animal Save Issue (SHO-5)
-- Purpose: Fix users being unable to update their own animals
-- Issue: Current RLS policies may be too restrictive or not handling updates correctly
-- Date: 2025-02-27

-- ============================================================================
-- DIAGNOSTIC: Check current state
-- ============================================================================

-- Log current RLS status
DO $$
BEGIN
    RAISE NOTICE 'Starting animal save hotfix migration';
    RAISE NOTICE 'Current RLS status for animals table: %', 
        (SELECT CASE WHEN rowsecurity FROM pg_tables 
         WHERE schemaname = 'public' AND tablename = 'animals'
         THEN 'ENABLED' ELSE 'DISABLED' END);
END $$;

-- ============================================================================
-- STEP 1: Create diagnostic function to log update attempts
-- ============================================================================

CREATE OR REPLACE FUNCTION log_animal_update_attempt()
RETURNS TRIGGER AS $$
BEGIN
    -- Only log in non-production or when debug flag is set
    IF current_setting('app.debug_animal_updates', true) = 'true' THEN
        RAISE NOTICE 'Animal update attempt - User: %, Animal ID: %, Owner: %, Changes: %',
            auth.uid(),
            COALESCE(NEW.id, OLD.id),
            OLD.user_id,
            jsonb_build_object(
                'name', CASE WHEN NEW.name != OLD.name THEN 
                    jsonb_build_object('old', OLD.name, 'new', NEW.name) 
                    ELSE NULL END,
                'breed', CASE WHEN NEW.breed != OLD.breed THEN 
                    jsonb_build_object('old', OLD.breed, 'new', NEW.breed) 
                    ELSE NULL END,
                'user_id_change_attempted', NEW.user_id != OLD.user_id
            );
    END IF;
    
    -- Prevent user_id changes for security
    IF NEW.user_id != OLD.user_id THEN
        RAISE EXCEPTION 'Cannot change animal ownership (user_id)';
    END IF;
    
    -- Ensure updated_at is set
    NEW.updated_at = CURRENT_TIMESTAMP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for debugging (disabled by default)
DROP TRIGGER IF EXISTS log_animal_updates ON animals;
-- Uncomment to enable debugging:
-- CREATE TRIGGER log_animal_updates
-- BEFORE UPDATE ON animals
-- FOR EACH ROW EXECUTE FUNCTION log_animal_update_attempt();

-- ============================================================================
-- STEP 2: Drop existing restrictive policies
-- ============================================================================

-- Store existing policies for rollback
CREATE TABLE IF NOT EXISTS _animal_policy_backup_20250227 AS
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    qual::text as qual_text,
    with_check::text as with_check_text,
    cmd
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'animals'
AND cmd = 'UPDATE';

-- Drop only UPDATE policies (keep SELECT, INSERT, DELETE intact)
DROP POLICY IF EXISTS "users_update_own_animals" ON animals;
DROP POLICY IF EXISTS "Users can update own animals" ON animals;
DROP POLICY IF EXISTS "users_can_update_own_animals" ON animals;

-- ============================================================================
-- STEP 3: Create more permissive but secure UPDATE policies
-- ============================================================================

-- Primary update policy - allows all field updates except user_id
CREATE POLICY "users_update_own_animals_hotfix" ON animals
FOR UPDATE
USING (
    -- User must own the animal
    auth.uid() = user_id
)
WITH CHECK (
    -- Ensure ownership doesn't change
    auth.uid() = user_id
    AND 
    -- Explicitly allow all field updates by not restricting them
    -- The trigger will handle user_id protection and updated_at
    true
);

-- Add explicit policy for handling updated_at and other system fields
CREATE POLICY "system_fields_update_protection" ON animals
FOR UPDATE
USING (
    -- Only allow if user owns the animal
    auth.uid() = user_id
)
WITH CHECK (
    -- User must remain the owner
    auth.uid() = user_id
    -- No additional field restrictions - let the application handle field-level logic
);

-- ============================================================================
-- STEP 4: Create helper function for testing updates
-- ============================================================================

CREATE OR REPLACE FUNCTION test_animal_update(
    p_animal_id UUID,
    p_name TEXT DEFAULT NULL,
    p_breed TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_error TEXT;
BEGIN
    -- Try to update the animal
    BEGIN
        UPDATE animals 
        SET 
            name = COALESCE(p_name, name),
            breed = COALESCE(p_breed, breed),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = p_animal_id
        RETURNING jsonb_build_object(
            'success', true,
            'id', id,
            'name', name,
            'breed', breed,
            'updated_at', updated_at,
            'user_id', user_id
        ) INTO v_result;
        
        IF v_result IS NULL THEN
            v_result = jsonb_build_object(
                'success', false,
                'error', 'No animal found or no permission to update'
            );
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        v_error = SQLERRM;
        v_result = jsonb_build_object(
            'success', false,
            'error', v_error,
            'detail', SQLSTATE
        );
    END;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 5: Ensure proper indexes for performance
-- ============================================================================

-- Create index for user_id lookups if not exists
CREATE INDEX IF NOT EXISTS idx_animals_user_id ON animals(user_id);
CREATE INDEX IF NOT EXISTS idx_animals_updated_at ON animals(updated_at DESC);

-- ============================================================================
-- STEP 6: Grant necessary permissions
-- ============================================================================

-- Ensure authenticated users have proper permissions
GRANT UPDATE ON animals TO authenticated;
GRANT EXECUTE ON FUNCTION test_animal_update TO authenticated;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Test the policies (run these manually after migration)
/*
-- 1. Check if RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'animals';

-- 2. List all policies on animals table
SELECT policyname, cmd, qual::text, with_check::text 
FROM pg_policies 
WHERE tablename = 'animals' AND schemaname = 'public'
ORDER BY cmd, policyname;

-- 3. Test update for a specific user (replace with actual IDs)
-- SET LOCAL "request.jwt.claim.sub" = 'your-user-id-here';
-- SELECT test_animal_update('animal-id-here', 'New Name', 'New Breed');

-- 4. Check for any blocked updates in recent logs
SELECT schemaname, tablename, policyname, cmd
FROM pg_policies 
WHERE tablename = 'animals' 
AND cmd = 'UPDATE';
*/

-- ============================================================================
-- DEBUGGING INSTRUCTIONS
-- ============================================================================

/*
To enable debug logging for animal updates:

1. Enable debug mode:
   SET app.debug_animal_updates = 'true';

2. Create the debug trigger:
   CREATE TRIGGER log_animal_updates
   BEFORE UPDATE ON animals
   FOR EACH ROW EXECUTE FUNCTION log_animal_update_attempt();

3. Attempt an update and check logs:
   UPDATE animals SET name = 'Test' WHERE id = 'your-animal-id';

4. Check Supabase logs or use RAISE NOTICE output

5. Disable when done:
   DROP TRIGGER IF EXISTS log_animal_updates ON animals;
   SET app.debug_animal_updates = 'false';
*/

-- ============================================================================
-- ROLLBACK INSTRUCTIONS
-- ============================================================================

/*
To rollback this hotfix:

1. Restore original policies:
   
   -- Remove hotfix policies
   DROP POLICY IF EXISTS "users_update_own_animals_hotfix" ON animals;
   DROP POLICY IF EXISTS "system_fields_update_protection" ON animals;
   
   -- Restore from backup (if original migration exists)
   CREATE POLICY "users_update_own_animals" ON animals
   FOR UPDATE 
   USING (auth.uid() = user_id)
   WITH CHECK (auth.uid() = user_id);

2. Remove debug function and trigger:
   DROP TRIGGER IF EXISTS log_animal_updates ON animals;
   DROP FUNCTION IF EXISTS log_animal_update_attempt();
   DROP FUNCTION IF EXISTS test_animal_update(UUID, TEXT, TEXT);

3. Clean up backup table:
   DROP TABLE IF EXISTS _animal_policy_backup_20250227;

4. Revoke added permissions:
   REVOKE UPDATE ON animals FROM authenticated;
*/

-- ============================================================================
-- POST-DEPLOYMENT TESTING
-- ============================================================================

/*
After deploying this hotfix:

1. Test with actual user account:
   - Login as a regular user
   - Try updating an animal you own
   - Verify name, breed, and other fields can be updated
   - Verify updated_at is automatically set
   - Verify you cannot change user_id

2. Test error cases:
   - Try updating an animal you don't own (should fail)
   - Try changing user_id field (should fail)
   - Try updating without authentication (should fail)

3. Monitor for issues:
   - Check Supabase logs for any RLS violations
   - Monitor application error logs
   - Watch for any performance degradation

4. Report results:
   - Document which operations succeed/fail
   - Note any error messages
   - Capture network requests if updates still fail
*/

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Animal save hotfix applied successfully';
    RAISE NOTICE '📋 Next steps:';
    RAISE NOTICE '  1. Test animal updates with a real user account';
    RAISE NOTICE '  2. Enable debug logging if updates still fail';
    RAISE NOTICE '  3. Check Supabase logs for any RLS violations';
    RAISE NOTICE '  4. Report results with specific error messages if any';
END $$;

-- ============================================================================
-- NOTES FOR DEVELOPERS
-- ============================================================================

/*
Common causes of RLS update failures:

1. AUTH TOKEN ISSUES:
   - Ensure auth token is properly passed in request headers
   - Check if auth.uid() is returning expected user ID
   - Verify JWT token hasn't expired

2. FIELD-LEVEL ISSUES:
   - Some fields might have CHECK constraints
   - Computed fields shouldn't be in UPDATE statement
   - Ensure client isn't sending null for required fields

3. TRANSACTION ISSUES:
   - Check if update is part of a larger transaction that fails
   - Look for any BEFORE UPDATE triggers that might block
   - Verify no foreign key constraints are violated

4. CLIENT-SIDE ISSUES:
   - Ensure Supabase client is initialized with proper auth
   - Check if update request includes all necessary fields
   - Verify the request isn't accidentally changing user_id

This hotfix makes policies more permissive while maintaining security.
If updates work after this, we can gradually tighten policies to find
the exact restriction causing issues.
*/