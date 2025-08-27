-- Migration: Fix Critical Security Vulnerabilities in Animals Table
-- Date: 2025-02-27
-- Priority: CRITICAL - Fixes unauthorized data access vulnerabilities
-- 
-- This migration:
-- 1. Enables Row Level Security (RLS) on the animals table
-- 2. Creates strict security policies for authenticated users
-- 3. Adds unique constraint on tag field scoped to user_id
-- 4. Ensures data isolation between users
--
-- WARNING: This migration will immediately enforce data access restrictions.
-- Ensure all application code uses proper authentication before running.

-- ============================================================================
-- STEP 1: Enable Row Level Security
-- ============================================================================
-- This immediately blocks all access until policies are created
ALTER TABLE public.animals ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 2: Drop existing policies if they exist (idempotent)
-- ============================================================================
DROP POLICY IF EXISTS "Users can view own animals" ON public.animals;
DROP POLICY IF EXISTS "Users can insert own animals" ON public.animals;
DROP POLICY IF EXISTS "Users can update own animals" ON public.animals;
DROP POLICY IF EXISTS "Users can delete own animals" ON public.animals;

-- ============================================================================
-- STEP 3: Create Security Policies
-- ============================================================================

-- Policy: Users can only SELECT their own animals
CREATE POLICY "Users can view own animals" 
ON public.animals 
FOR SELECT 
USING (
    auth.uid() = user_id
);

-- Policy: Users can only INSERT animals with their own user_id
CREATE POLICY "Users can insert own animals" 
ON public.animals 
FOR INSERT 
WITH CHECK (
    auth.uid() = user_id
);

-- Policy: Users can only UPDATE their own animals
CREATE POLICY "Users can update own animals" 
ON public.animals 
FOR UPDATE 
USING (
    auth.uid() = user_id
)
WITH CHECK (
    auth.uid() = user_id
);

-- Policy: Users can only DELETE their own animals
CREATE POLICY "Users can delete own animals" 
ON public.animals 
FOR DELETE 
USING (
    auth.uid() = user_id
);

-- ============================================================================
-- STEP 4: Add Unique Constraint on Tag (scoped to user_id)
-- ============================================================================
-- Drop existing constraint if it exists
ALTER TABLE public.animals 
DROP CONSTRAINT IF EXISTS animals_user_tag_unique;

-- Create new unique constraint (tag must be unique per user)
ALTER TABLE public.animals 
ADD CONSTRAINT animals_user_tag_unique 
UNIQUE (user_id, tag);

-- ============================================================================
-- STEP 5: Create indexes for performance
-- ============================================================================
-- Ensure efficient policy evaluation
CREATE INDEX IF NOT EXISTS idx_animals_user_id 
ON public.animals(user_id);

-- Ensure efficient tag lookups
CREATE INDEX IF NOT EXISTS idx_animals_tag 
ON public.animals(tag);

-- ============================================================================
-- STEP 6: Add security-related comments
-- ============================================================================
COMMENT ON TABLE public.animals IS 
'Core table for livestock tracking. RLS enabled - users can only access their own animals.';

COMMENT ON POLICY "Users can view own animals" ON public.animals IS 
'Security Policy: Ensures users can only view animals they own';

COMMENT ON POLICY "Users can insert own animals" ON public.animals IS 
'Security Policy: Prevents users from creating animals for other users';

COMMENT ON POLICY "Users can update own animals" ON public.animals IS 
'Security Policy: Ensures users can only modify their own animals';

COMMENT ON POLICY "Users can delete own animals" ON public.animals IS 
'Security Policy: Ensures users can only delete their own animals';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these after migration to verify security is properly configured

-- Check RLS is enabled
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'animals' 
        AND rowsecurity = true
    ) THEN
        RAISE EXCEPTION 'CRITICAL: RLS is not enabled on animals table!';
    END IF;
    
    RAISE NOTICE 'SUCCESS: RLS is enabled on animals table';
END $$;

-- Verify all policies are created
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public' 
    AND tablename = 'animals';
    
    IF policy_count < 4 THEN
        RAISE EXCEPTION 'CRITICAL: Expected 4 policies, found %', policy_count;
    END IF;
    
    RAISE NOTICE 'SUCCESS: All % security policies are active', policy_count;
END $$;

-- Verify unique constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'animals_user_tag_unique'
    ) THEN
        RAISE EXCEPTION 'CRITICAL: Unique constraint on (user_id, tag) not found!';
    END IF;
    
    RAISE NOTICE 'SUCCESS: Unique constraint on (user_id, tag) is active';
END $$;

-- ============================================================================
-- ROLLBACK INSTRUCTIONS (EMERGENCY USE ONLY)
-- ============================================================================
-- WARNING: Rolling back will remove all security policies and leave data exposed!
-- Only use if the migration causes critical application failures.
--
-- To rollback, run the following commands:
/*
-- ROLLBACK START --

-- Remove security policies
DROP POLICY IF EXISTS "Users can view own animals" ON public.animals;
DROP POLICY IF EXISTS "Users can insert own animals" ON public.animals;
DROP POLICY IF EXISTS "Users can update own animals" ON public.animals;
DROP POLICY IF EXISTS "Users can delete own animals" ON public.animals;

-- Disable RLS (WARNING: This exposes all data!)
ALTER TABLE public.animals DISABLE ROW LEVEL SECURITY;

-- Remove unique constraint
ALTER TABLE public.animals DROP CONSTRAINT IF EXISTS animals_user_tag_unique;

-- Remove indexes (optional, they don't hurt to keep)
-- DROP INDEX IF EXISTS idx_animals_user_id;
-- DROP INDEX IF EXISTS idx_animals_tag;

-- ROLLBACK END --
*/

-- ============================================================================
-- POST-MIGRATION TESTING CHECKLIST
-- ============================================================================
/*
After running this migration, test the following scenarios:

1. User Authentication Test:
   - [ ] Verify users must be authenticated to access animals table
   - [ ] Verify unauthenticated requests are rejected

2. Data Isolation Test:
   - [ ] Create test animals for User A
   - [ ] Login as User B
   - [ ] Verify User B cannot see User A's animals
   - [ ] Verify User B cannot modify User A's animals

3. CRUD Operations Test:
   - [ ] User can CREATE their own animals
   - [ ] User can READ their own animals
   - [ ] User can UPDATE their own animals
   - [ ] User can DELETE their own animals
   - [ ] User cannot perform any operations on other users' animals

4. Unique Tag Test:
   - [ ] User cannot create two animals with the same tag
   - [ ] Different users CAN have animals with the same tag

5. Performance Test:
   - [ ] Queries with user_id filter are performant
   - [ ] Tag lookups are performant

6. Application Integration Test:
   - [ ] All existing app features work correctly with RLS enabled
   - [ ] No authorization errors in normal user workflows

CRITICAL: If any test fails, investigate immediately and consider rollback if necessary.
*/

-- ============================================================================
-- NOTES FOR DEVELOPERS
-- ============================================================================
/*
IMPORTANT: After this migration, all queries to the animals table will be 
automatically filtered by the authenticated user's ID. This means:

1. No need to add "WHERE user_id = ?" in application queries
2. Supabase client MUST be authenticated before querying
3. Service role keys bypass RLS - use with extreme caution
4. For admin features, consider creating separate admin policies

Example application code after migration:

// JavaScript/TypeScript
const { data, error } = await supabase
  .from('animals')
  .select('*')
  // No need for .eq('user_id', userId) - RLS handles this!

// The query automatically returns only the authenticated user's animals

SECURITY REMINDER: Never use service role keys in client-side code!
*/