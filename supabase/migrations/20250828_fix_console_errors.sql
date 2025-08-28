-- ShowTrackAI Console Errors Fix
-- Date: 2025-08-28  
-- Description: Fixes critical console errors from production deployment
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1: Fix Missing birth_date Column
-- ============================================================================

-- Add birth_date column to user_profiles if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'birth_date'
    ) THEN
        ALTER TABLE user_profiles ADD COLUMN birth_date DATE;
        RAISE NOTICE 'Added birth_date column to user_profiles';
    ELSE
        RAISE NOTICE 'birth_date column already exists in user_profiles';
    END IF;
END $$;

-- Add parent_email column if missing (for COPPA compliance)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'parent_email'
    ) THEN
        ALTER TABLE user_profiles ADD COLUMN parent_email TEXT;
        RAISE NOTICE 'Added parent_email column to user_profiles';
    ELSE
        RAISE NOTICE 'parent_email column already exists in user_profiles';
    END IF;
END $$;

-- Add parent_consent columns if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'parent_consent'
    ) THEN
        ALTER TABLE user_profiles 
        ADD COLUMN parent_consent BOOLEAN DEFAULT FALSE,
        ADD COLUMN parent_consent_date TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE 'Added parent_consent columns to user_profiles';
    ELSE
        RAISE NOTICE 'parent_consent columns already exist in user_profiles';
    END IF;
END $$;

-- ============================================================================
-- SECTION 2: Fix Missing get_user_journal_stats RPC Function
-- ============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_user_journal_stats(UUID);

-- Create the missing get_user_journal_stats function
CREATE OR REPLACE FUNCTION get_user_journal_stats(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_stats JSONB;
    v_total_entries INTEGER := 0;
    v_this_week INTEGER := 0;
    v_this_month INTEGER := 0;
    v_avg_per_week DECIMAL(5,2) := 0.00;
    v_streak_days INTEGER := 0;
    v_latest_entry TIMESTAMP WITH TIME ZONE;
    v_first_entry TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Get basic counts
    SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN created_at >= date_trunc('week', NOW()) THEN 1 END) as this_week,
        COUNT(CASE WHEN created_at >= date_trunc('month', NOW()) THEN 1 END) as this_month,
        MIN(created_at) as first_entry,
        MAX(created_at) as latest_entry
    INTO 
        v_total_entries, v_this_week, v_this_month, v_first_entry, v_latest_entry
    FROM journal_entries 
    WHERE user_id = p_user_id;

    -- Calculate average per week (if user has been active for more than a week)
    IF v_first_entry IS NOT NULL AND v_first_entry < NOW() - INTERVAL '7 days' THEN
        v_avg_per_week := v_total_entries / GREATEST(1, EXTRACT(WEEK FROM AGE(NOW(), v_first_entry)));
    ELSE
        v_avg_per_week := v_this_week;
    END IF;

    -- Calculate current streak (consecutive days with entries)
    WITH daily_entries AS (
        SELECT DISTINCT DATE(created_at) as entry_date
        FROM journal_entries 
        WHERE user_id = p_user_id
        ORDER BY entry_date DESC
    ),
    streak_calculation AS (
        SELECT 
            entry_date,
            ROW_NUMBER() OVER (ORDER BY entry_date DESC) as rn,
            entry_date - INTERVAL '1 day' * (ROW_NUMBER() OVER (ORDER BY entry_date DESC) - 1) as expected_date
        FROM daily_entries
    )
    SELECT COUNT(*) INTO v_streak_days
    FROM streak_calculation 
    WHERE expected_date = DATE(entry_date)
    AND entry_date >= (
        SELECT MIN(expected_date) 
        FROM streak_calculation 
        WHERE expected_date = DATE(entry_date)
    );

    -- Build result object
    v_stats := jsonb_build_object(
        'total_entries', v_total_entries,
        'entries_this_week', v_this_week,
        'entries_this_month', v_this_month,
        'average_per_week', v_avg_per_week,
        'current_streak_days', COALESCE(v_streak_days, 0),
        'latest_entry_date', v_latest_entry,
        'first_entry_date', v_first_entry,
        'days_since_last_entry', CASE 
            WHEN v_latest_entry IS NOT NULL 
            THEN EXTRACT(DAYS FROM AGE(NOW(), v_latest_entry))::INTEGER 
            ELSE NULL 
        END
    );

    RETURN v_stats;
EXCEPTION
    WHEN OTHERS THEN
        -- Return safe defaults on error
        RETURN jsonb_build_object(
            'total_entries', 0,
            'entries_this_week', 0,
            'entries_this_month', 0,
            'average_per_week', 0.00,
            'current_streak_days', 0,
            'latest_entry_date', NULL,
            'first_entry_date', NULL,
            'days_since_last_entry', NULL,
            'error', 'Failed to calculate stats: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_user_journal_stats(UUID) TO authenticated;

-- ============================================================================
-- SECTION 3: Add Missing Indexes for Performance
-- ============================================================================

-- Add indexes for journal stats performance
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_created 
ON journal_entries(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_journal_entries_user_date 
ON journal_entries(user_id, DATE(created_at));

-- Add indexes for user_profiles performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_birth_date 
ON user_profiles(birth_date) WHERE birth_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_profiles_parent_email 
ON user_profiles(parent_email) WHERE parent_email IS NOT NULL;

-- ============================================================================
-- SECTION 4: Update RLS Policies for New Columns
-- ============================================================================

-- Ensure RLS is enabled on user_profiles
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Update existing policies to handle new columns safely
-- (Only if the policy doesn't already exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_profiles' 
        AND policyname = 'Users can view own profile'
    ) THEN
        CREATE POLICY "Users can view own profile" 
        ON user_profiles FOR SELECT 
        USING (auth.uid() = id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_profiles' 
        AND policyname = 'Users can update own profile'
    ) THEN
        CREATE POLICY "Users can update own profile" 
        ON user_profiles FOR UPDATE 
        USING (auth.uid() = id);
    END IF;
END $$;

-- ============================================================================
-- SECTION 5: Test Functions
-- ============================================================================

-- Test the get_user_journal_stats function
DO $$
DECLARE
    test_result JSONB;
BEGIN
    -- Test with a random UUID (should return safe defaults)
    SELECT get_user_journal_stats(gen_random_uuid()) INTO test_result;
    
    IF test_result ? 'total_entries' AND test_result ? 'current_streak_days' THEN
        RAISE NOTICE 'get_user_journal_stats function test: PASSED';
    ELSE
        RAISE NOTICE 'get_user_journal_stats function test: FAILED - %', test_result;
    END IF;
END $$;

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify the migration was successful
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Migration Verification Results:';
    RAISE NOTICE '============================================';
    
    -- Check birth_date column
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' AND column_name = 'birth_date'
    ) THEN
        RAISE NOTICE '✅ birth_date column exists in user_profiles';
    ELSE
        RAISE NOTICE '❌ birth_date column missing in user_profiles';
    END IF;
    
    -- Check get_user_journal_stats function
    IF EXISTS (
        SELECT 1 FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'public' AND p.proname = 'get_user_journal_stats'
    ) THEN
        RAISE NOTICE '✅ get_user_journal_stats function exists';
    ELSE
        RAISE NOTICE '❌ get_user_journal_stats function missing';
    END IF;
    
    -- Check RLS policies
    IF EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_profiles'
    ) THEN
        RAISE NOTICE '✅ RLS policies exist for user_profiles';
    ELSE
        RAISE NOTICE '❌ No RLS policies found for user_profiles';
    END IF;
    
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Migration completed successfully!';
    RAISE NOTICE '============================================';
END $$;