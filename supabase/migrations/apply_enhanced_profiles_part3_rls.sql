-- ============================================================================
-- PART 3: ROW LEVEL SECURITY POLICIES
-- ============================================================================
-- Run this after Part 2 is successful

-- Enable RLS on all new tables
ALTER TABLE ffa_chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE ffa_degrees ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ffa_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE skills_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_skills ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (safe operation)
DROP POLICY IF EXISTS "ffa_chapters_select_policy" ON ffa_chapters;
DROP POLICY IF EXISTS "ffa_chapters_admin_only" ON ffa_chapters;
DROP POLICY IF EXISTS "ffa_degrees_select_policy" ON ffa_degrees;
DROP POLICY IF EXISTS "user_ffa_progress_select_policy" ON user_ffa_progress;
DROP POLICY IF EXISTS "user_ffa_progress_insert_policy" ON user_ffa_progress;
DROP POLICY IF EXISTS "user_ffa_progress_update_policy" ON user_ffa_progress;
DROP POLICY IF EXISTS "skills_catalog_select_policy" ON skills_catalog;
DROP POLICY IF EXISTS "skills_catalog_admin_only" ON skills_catalog;
DROP POLICY IF EXISTS "user_skills_select_policy" ON user_skills;
DROP POLICY IF EXISTS "user_skills_insert_policy" ON user_skills;
DROP POLICY IF EXISTS "user_skills_update_policy" ON user_skills;
DROP POLICY IF EXISTS "user_skills_delete_policy" ON user_skills;

-- FFA Chapters policies (public read, admin write)
CREATE POLICY "ffa_chapters_select_policy" ON ffa_chapters 
    FOR SELECT USING (TRUE);

CREATE POLICY "ffa_chapters_admin_only" ON ffa_chapters 
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND user_role IN ('admin', 'educator')
        )
    );

-- FFA Degrees policies (public read)
CREATE POLICY "ffa_degrees_select_policy" ON ffa_degrees 
    FOR SELECT USING (is_active = TRUE);

-- User FFA Progress policies
CREATE POLICY "user_ffa_progress_select_policy" ON user_ffa_progress 
    FOR SELECT USING (
        auth.uid() = user_id
        OR EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND user_role IN ('admin', 'educator')
        )
    );

CREATE POLICY "user_ffa_progress_insert_policy" ON user_ffa_progress 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_ffa_progress_update_policy" ON user_ffa_progress 
    FOR UPDATE USING (
        auth.uid() = user_id
        OR (
            EXISTS (
                SELECT 1 FROM user_profiles 
                WHERE id = auth.uid() 
                AND user_role IN ('admin', 'educator')
            )
            AND verification_status = 'submitted'
        )
    );

-- Skills Catalog policies (public read, admin write)
CREATE POLICY "skills_catalog_select_policy" ON skills_catalog 
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY "skills_catalog_admin_only" ON skills_catalog 
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND user_role IN ('admin', 'educator')
        )
    );

-- User Skills policies
CREATE POLICY "user_skills_select_policy" ON user_skills 
    FOR SELECT USING (
        auth.uid() = user_id
        OR EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND user_role IN ('admin', 'educator')
        )
    );

CREATE POLICY "user_skills_insert_policy" ON user_skills 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_skills_update_policy" ON user_skills 
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "user_skills_delete_policy" ON user_skills 
    FOR DELETE USING (auth.uid() = user_id);

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ffa_chapters TO authenticated;
GRANT SELECT ON ffa_degrees TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_ffa_progress TO authenticated;
GRANT SELECT ON skills_catalog TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_skills TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================================
-- VERIFICATION QUERY 3: Check RLS Policies
-- ============================================================================

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('ffa_chapters', 'ffa_degrees', 'user_ffa_progress', 'skills_catalog', 'user_skills')
ORDER BY tablename, policyname;